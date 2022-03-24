//
//  Cache.swift
//  Beam
//
//  Created by Remi Santos on 21/10/2021.
//

import Foundation
import BeamCore

/**
 Generic Wrapper around NSCache

 Allowing a much more flexible Swift interface
 And adding capabilities like file persitence.

 Largely inspired by https://www.swiftbysundell.com/articles/caching-in-swift/

 */
final class Cache<Key: Hashable, Value> {
    private let wrapped = NSCache<WrappedKey, Entry>()
    private let keyTracker = KeyTracker()

    var countLimit: Int {
        wrapped.countLimit
    }

    var numberOfValues: Int {
        keyTracker.keys.count
    }

    init(countLimit: Int) {
        wrapped.countLimit = countLimit
        wrapped.delegate = keyTracker
    }

    func insert(_ value: Value, forKey key: Key) {
        let entry = Entry(key: key, value: value)
        insert(entry)
    }

    fileprivate func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }

    func value(forKey key: Key) -> Value? {
        let entry = entry(forKey: key)
        return entry?.value
    }

    fileprivate func entry(forKey key: Key) -> Entry? {
        wrapped.object(forKey: WrappedKey(key))
    }

    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }

    func removeAllValues() {
        wrapped.removeAllObjects()
    }

    subscript(key: Key) -> Value? {
        get { return value(forKey: key) }
        set {
            guard let value = newValue else {
                // If nil was assigned using our subscript,
                // then we remove any value for that key:
                removeValue(forKey: key)
                return
            }

            insert(value, forKey: key)
        }
    }
}

private extension Cache {
    final class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }

        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey)?.key == key
        }
    }

    final class KeyTracker: NSObject, NSCacheDelegate {
        var keys = Set<Key>()
        func cache(_ cache: NSCache<AnyObject, AnyObject>,
                   willEvictObject object: Any) {
            guard let entry = object as? Entry else { return }
            keys.remove(entry.key)
        }
    }
}

private extension Cache {
    final class Entry {
        let key: Key
        let value: Value

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
}

// MARK: - Codable support
extension Cache.Entry: Codable where Key: Codable, Value: Codable {}
extension Cache: Codable where Key: Codable, Value: Codable {

    enum CodingKeys: String, CodingKey {
        case entries
        case countLimit
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let countLimit = try container.decode(Int.self, forKey: .countLimit)
        self.init(countLimit: countLimit)

        let entries = try container.decode([Entry].self, forKey: .entries)
        entries.forEach(insert)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyTracker.keys.compactMap(entry), forKey: .entries)
        try container.encode(wrapped.countLimit, forKey: .countLimit)
    }

    func saveToDisk(withName name: String, using fileManager: FileManager = .default) throws {
        let folderURLs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        let fileURL = folderURLs[0].appendingPathComponent(name + ".cache")
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL)
    }

    static func recoverFromDisk(withName name: String, using fileManager: FileManager = .default) throws -> Cache<Key, Value> {
        let folderURLs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        let fileURL = folderURLs[0].appendingPathComponent(name + ".cache")
        let data = try Data(contentsOf: fileURL)
        let cache = try BeamJSONDecoder().decode(self, from: data)
        return cache
    }

    /// Creates a cache on disk or recovers an existing one with the same name.
    static func diskCache(filename: String, countLimit: Int) -> Cache<Key, Value> {
        if let cache = try? Cache<Key, Value>.recoverFromDisk(withName: filename) {
            return cache
        } else {
            return Cache<Key, Value>(countLimit: countLimit)
        }
    }

}
