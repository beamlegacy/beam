//
//  EmbedContentCache.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation
import BeamCore

class EmbedContentCache {
    static let shared = EmbedContentCache()
    private let cache = Cache<String, EmbedContent>(countLimit: 100)
    func cachedEmbedContent(for urlString: String) -> EmbedContent? {
        cache.value(forKey: urlString)
    }
    func saveEmbedContent(_ embedContent: EmbedContent, for urlString: String) {
        if let cachedEmbedContent = cache.value(forKey: urlString),
           embedContent == cachedEmbedContent {
            Logger.shared.logDebug("Cached EmbedContent is Equal to embedContent. Skipping saving embed content to cache", category: .embed)
            return
        }
        cache.insert(embedContent, forKey: urlString)
    }
    func clear() { cache.removeAllValues() }
}
