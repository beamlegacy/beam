//
//  FaviconProvider.swift
//  Beam
//
//  Created by Remi Santos on 12/03/2021.
//

import Foundation
import FavIcon
import BeamCore

final class FaviconProvider {

    static let shared = FaviconProvider()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 100
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }

    private func cacheKeyForURL(_ url: URL, size: Int) -> NSString {
        return NSString(string: url.host ?? url.urlStringWithoutScheme).appendingFormat("-%d", size)
    }

    func imageForUrl(_ url: URL, size: Int = 16, cacheOnly: Bool = false, handler: @escaping(NSImage?) -> Void) {
        let scaledSize = Int(CGFloat(size) * screenScale)
        let cacheKey = cacheKeyForURL(url, size: scaledSize)
        if let cached = cache.object(forKey: cacheKey) {
            handler(cached)
            return
        } else if cacheOnly {
            handler(nil)
            return
        }
        do {
            try FavIcon.downloadPreferred(url, width: scaledSize, height: scaledSize) { [weak self] result in
                if case let .success(image) = result {
                    guard let self = self else {
                        return
                    }
                    self.cache.setObject(image, forKey: cacheKey)
                    handler(image)
                    return
                } else if case let .failure(error) = result {
                    Logger.shared.logDebug("FaviconProvider failure: \(error.localizedDescription)", category: .favIcon)
                }
                handler(nil)
            }
        } catch let error {
            Logger.shared.logDebug("FaviconProvider error: \(error.localizedDescription)", category: .favIcon)
            handler(nil)
        }
    }
}
