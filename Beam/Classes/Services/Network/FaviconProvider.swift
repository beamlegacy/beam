//
//  FaviconProvider.swift
//  Beam
//
//  Created by Remi Santos on 12/03/2021.
//

import Foundation
import FavIcon

final class FaviconProvider {

    static let shared = FaviconProvider()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 100
    }

    private func cacheKeyForURL(_ url: URL) -> NSString {
        return NSString(string: url.host ?? url.urlStringWithoutScheme)
    }

    func imageForUrl(_ url: URL, cacheOnly: Bool = false, handler: @escaping(NSImage?) -> Void) {
        let cacheKey = cacheKeyForURL(url)
        if let cached = cache.object(forKey: cacheKey) {
            handler(cached)
            return
        } else if cacheOnly {
            handler(nil)
            return
        }
        do {
            try FavIcon.downloadPreferred(url, width: 16, height: 16) { [weak self] result in
                if case let .success(image) = result {
                    guard let self = self else {
                        return
                    }
                    self.cache.setObject(image, forKey: cacheKey)
                    handler(image)
                    return
                } else if case let .failure(error) = result {
                    Logger.shared.logDebug("FaviconProvider failure: \(error.localizedDescription)")
                }
                handler(nil)
            }
        } catch let error {
            Logger.shared.logDebug("FaviconProvider error: \(error.localizedDescription)")
            handler(nil)
        }
    }
}
