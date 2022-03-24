//
//  EmbedContentBuilder.swift
//  Beam
//
//  Created by Remi Santos on 03/11/2021.
//

import Foundation
import Combine
import BeamCore

enum EmbedContentError: Error, Equatable {
    case notEmbeddable
    case noSuitableStrategy
}

struct EmbedContentBuilder {
    var strategies: [EmbedContentStrategy]
    private var useCache = true

    private var syncStrategy: EmbedContentStrategy? {
        strategies.first
    }

    private var asyncStrategy: EmbedContentStrategy? {
        strategies.last
    }

    init() {
        strategies = [EmbedContentLocalStrategy(), EmbedContentAPIStrategy()]
    }

    private func cachedEmbed(for url: URL) -> EmbedContent? {
        guard useCache else { return nil }
        return EmbedContentCache.shared.cachedEmbedContent(for: url.absoluteString)
    }

    func clearCache() {
        EmbedContentCache.shared.clear()
    }

    func canBuildEmbed(for url: URL) -> Bool {
        if cachedEmbed(for: url) != nil {
            return true
        }
        for strategy in strategies {
            if strategy.canBuildEmbeddableContent(for: url) {
                return true
            }
        }
        return false
    }

    func embedMatchURL(for url: URL) -> URL? {
        for strategy in strategies {
            if let url = strategy.embedMatchURL(for: url) {
                return url
            }
        }
        return nil
    }

    func embeddableContent(for url: URL) -> EmbedContent? {
        var result = cachedEmbed(for: url)
        if result == nil, let strategy = syncStrategy {
            Logger.shared.logDebug("EmbedURLBuilder sync strategy for \(url.absoluteString)", category: .embed)
            strategy.embeddableContent(for: url) { embedContent, _ in
                if let content = embedContent, useCache {
                    EmbedContentCache.shared.saveEmbedContent(content, for: url.absoluteString)
                }
                result = embedContent
            }
        }
        return result
    }

    func embeddableContentAsync(for url: URL) -> Future<EmbedContent, EmbedContentError> {
        Future { promise in
            if let cached = cachedEmbed(for: url) {
                promise(.success(cached))
                return
            }
            Logger.shared.logDebug("EmbedURLBuilder async strategy for \(url.absoluteString)", category: .embed)
            guard let asyncStrategy = asyncStrategy else {
                promise(.failure(.noSuitableStrategy))
                return
            }

            asyncStrategy.embeddableContent(for: url) { embedContent, _ in
                if let embedContent = embedContent {
                    if useCache {
                        EmbedContentCache.shared.saveEmbedContent(embedContent, for: url.absoluteString)
                    }
                    promise(.success(embedContent))
                } else {
                    promise(.failure(.notEmbeddable))
                }
            }
        }
    }

    func embeddableContentFromAnyStrategy(for url: URL) -> Future<EmbedContent, EmbedContentError> {
        let embedContentBuilder = EmbedContentBuilder()

        if let embedContent = embedContentBuilder.embeddableContent(for: url) {
            return Future<EmbedContent, EmbedContentError> { promise in
                promise(.success(embedContent))
            }
        }

        return embedContentBuilder.embeddableContentAsync(for: url)
    }

}
