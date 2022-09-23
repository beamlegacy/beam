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
final class Cache<Key: Hashable, Value>: Caching {
    var wrapped: NSCache<CachingWrappedKey<Key>, CachingEntry<Key, Value>> = .init()
    var keyTracker: CachingKeyTracker<Key, Value> = .init()

    init(countLimit: Int) {
        wrapped.countLimit = countLimit
        wrapped.delegate = keyTracker
    }

}

/// Protocol to define a Caching manager.
/// Use available generic Cache class above for most cases.
protocol Caching: AnyObject {
    associatedtype Key: Hashable
    associatedtype Value
    typealias Entry = CachingEntry<Key, Value>
    var wrapped: NSCache<CachingWrappedKey<Key>, Entry> { get set }
    var keyTracker: CachingKeyTracker<Key, Value> { get set }

    init(countLimit: Int)
}

extension Caching {
    var countLimit: Int {
        wrapped.countLimit
    }

    var numberOfValues: Int {
        keyTracker.keys.count
    }

    var allEntries: [Entry] {
        keyTracker.keys.compactMap(entry)
    }

    func insert(_ value: Value, forKey key: Key) {
        let entry = CachingEntry(key: key, value: value)
        insert(entry)
    }

    fileprivate func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: CachingWrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }

    func value(forKey key: Key) -> Value? {
        let entry = entry(forKey: key)
        return entry?.value
    }

    fileprivate func entry(forKey key: Key) -> Entry? {
        wrapped.object(forKey: CachingWrappedKey(key))
    }

    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: CachingWrappedKey(key))
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

final class CachingWrappedKey<Key: Hashable>: NSObject {
    let key: Key
    init(_ key: Key) { self.key = key }

    override var hash: Int { key.hashValue }
    override func isEqual(_ object: Any?) -> Bool {
        (object as? CachingWrappedKey)?.key == key
    }
}

final class CachingKeyTracker<Key: Hashable, Value>: NSObject, NSCacheDelegate {
    var keys = Set<Key>()
    func cache(_ cache: NSCache<AnyObject, AnyObject>,
               willEvictObject object: Any) {
        guard let entry = object as? CachingEntry<Key, Value> else { return }
        keys.remove(entry.key)
    }
}

final class CachingEntry<Key: Hashable, Value> {
    let key: Key
    let value: Value

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

// MARK: - Codable Support
enum CachingCodingKeys: String, CodingKey {
    case entries
    case countLimit
}

extension CachingEntry: Codable where Key: Codable, Value: Codable {}

extension Caching where Key: Codable, Value: Codable, Self: Codable {

    private static var ext: String { "cache" }

    func saveToDisk(withName name: String, using fileManager: FileManager = .default) throws {
        let folderURLs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        let fileURL = folderURLs[0].appendingPathComponent(name).appendingPathExtension(Self.ext)
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL)
    }

    static func recoverFromDisk(withName name: String, using fileManager: FileManager = .default) throws -> Self {
        let folderURLs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)

        let fileURL = folderURLs[0].appendingPathComponent(name).appendingPathExtension(Self.ext)
        let data = try Data(contentsOf: fileURL)
        let cache = try BeamJSONDecoder().decode(self, from: data)
        return cache
    }

    /// Creates a cache on disk or recovers an existing one with the same name.
    static func diskCache(filename: String, countLimit: Int) -> Self {
        if let cache = try? Self.recoverFromDisk(withName: filename) {
            return cache
        } else {
            return Self.init(countLimit: countLimit)
        }
    }

}

extension Cache: Codable where Key: Codable, Value: Codable {
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CachingCodingKeys.self)
        let countLimit = try container.decode(Int.self, forKey: .countLimit)
        self.init(countLimit: countLimit)
        let entries = try container.decode([Entry].self, forKey: .entries)
        entries.forEach(insert)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CachingCodingKeys.self)
        try container.encode(wrapped.countLimit, forKey: .countLimit)
        try container.encode(keyTracker.keys.compactMap(entry), forKey: .entries)
    }
}
