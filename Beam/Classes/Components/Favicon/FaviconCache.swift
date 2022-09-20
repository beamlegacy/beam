//
//  FaviconCache.swift
//  Beam
//
//  Created by Remi Santos on 14/09/2022.
//

import Foundation

/**
 * A regular Cache<String, Favicon>.
 * Except that when encoding to save on disk, we remove the images from the entries
 * and save them in a dedicated dictionary to avoid duplicated data.
 *
 * Images are stripped from the values when encoding, and re-assembled when decoding.
 * Encoded structure:
 * ```
 * {
 *    entriesWithoutImage: [ values ],
 *    images: [ id: image]
 * }
 * ```
 */
final class FaviconCache: Caching, Codable {

    typealias Key = String
    typealias Value = Favicon
    var wrapped: NSCache<CachingWrappedKey<String>, Entry> = .init()
    var keyTracker: CachingKeyTracker<String, Favicon> = .init()

    required init(countLimit: Int) {
        wrapped.countLimit = countLimit
        wrapped.delegate = keyTracker
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CachingCodingKeys.self)
        let countLimit = try container.decode(Int.self, forKey: .countLimit)
        self.init(countLimit: countLimit)
        try self.decodeEntries(from: decoder)
    }

    enum AdditionalCodingKeys: String, CodingKey {
        case entriesWithoutImage
        case images
    }

    typealias ImagesDictionary = [UUID: ImageCodableWrapper]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CachingCodingKeys.self)
        try container.encode(wrapped.countLimit, forKey: .countLimit)
        try self.encodeEntries(to: encoder)
    }
    
    private func decodeEntries(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AdditionalCodingKeys.self)
        let entries = try container.decode([Entry].self, forKey: .entriesWithoutImage)
        let images = try container.decode(ImagesDictionary.self, forKey: .images)
        entries.forEach { entry in
            guard let imageId = entry.value.imageId else {
                insert(entry.value, forKey: entry.key)
                return
            }
            var copy = entry.value
            copy.image = images[imageId]?.image
            insert(copy, forKey: entry.key)
        }
    }

    private func encodeEntries(to encoder: Encoder) throws {
        var images: ImagesDictionary = [:]
        let entriesToEncode: [Entry] = allEntries.map { entry in
            let icon = entry.value
            guard let image = icon.image, let imageId = icon.imageId else {
                return entry
            }
            images[imageId] = ImageCodableWrapper(image: image)
            var copy = icon
            copy.image = nil
            return Entry(key: entry.key, value: copy)
        }
        var container = encoder.container(keyedBy: AdditionalCodingKeys.self)
        try container.encode(entriesToEncode, forKey: .entriesWithoutImage)
        try container.encode(images, forKey: .images)
    }

    private func migrateLegacyCache(_ legacyCache: Cache<String, Favicon>) {
        legacyCache.allEntries.forEach { entry in
            insert(entry.value, forKey: entry.key)
        }
    }

    // Add support for legacy format
    static func diskCache(filename: String, countLimit: Int) -> FaviconCache {
        if let cache = try? FaviconCache.recoverFromDisk(withName: filename) {
            return cache
        } else if let legacyCache = try? Cache<String, Favicon>.recoverFromDisk(withName: filename) {
            let cache = FaviconCache(countLimit: countLimit)
            cache.migrateLegacyCache(legacyCache)
            return cache
        }
        return Self.init(countLimit: countLimit)
    }
}
