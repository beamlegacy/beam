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

struct EmbedContent {
    enum EmbedContentType {
        case url
        case image
        case page
    }
    var sourceURL: URL
    var type: EmbedContentType
    var embedURL: URL?
    var embedContent: String?
}

private class EmbedContentCache {
    static let shared = EmbedContentCache()
    private let cache = Cache<String, EmbedContent>(countLimit: 100)
    func cachedEmbedContent(for urlString: String) -> EmbedContent? {
        cache.value(forKey: urlString)
    }
    func saveEmbedContent(_ embedContent: EmbedContent, for urlString: String) {
        cache.insert(embedContent, forKey: urlString)
    }
    func clear() { cache.removeAllValues() }
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
        strategies = [EmbedContentLocalStrategy()]
        if AuthenticationManager.shared.isAuthenticated {
            // for now the embed api is only available to logged in users
            strategies.append(EmbedContentAPIStrategy())
        }
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
}

// MARK: - Strategies

protocol EmbedContentStrategy {
    func canBuildEmbeddableContent(for url: URL) -> Bool
    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void)
}

/// Can build embed content from local synchronous parsing
struct EmbedContentLocalStrategy: EmbedContentStrategy {
    func canBuildEmbeddableContent(for url: URL) -> Bool {
        var canEmbed = false
        embeddableContent(for: url) { embedContent, _ in
            canEmbed = embedContent != nil
        }
        return canEmbed
    }

    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void) {
        var embedURL: URL?
        if let youtubeEmbed = youtubeEmbedURL(from: url) {
            embedURL = youtubeEmbed
        } else if url.path.contains("/embed/") {
            embedURL = url
        }
        var result: EmbedContent?
        if let embedURL = embedURL {
            result = EmbedContent(sourceURL: url, type: .url, embedURL: embedURL)
        }
        completion(result, result == nil ? .notEmbeddable : nil)
    }

    // MARK: Youtube
    private func youtubeEmbedURL(from url: URL) -> URL? {
        guard let youtubeID = extractYouTubeId(from: url) else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(youtubeID)")
    }

    private func extractYouTubeId(from url: URL) -> String? {
        let string = url.absoluteString
        let typePattern = "(?:(?:\\.be\\/|embed\\/|v\\/|\\?v=|\\&v=|\\/videos\\/)|(?:[\\w+]+#\\w\\/\\w(?:\\/[\\w]+)?\\/\\w\\/))([\\w-_]+)"
        let regex = try? NSRegularExpression(pattern: typePattern, options: .caseInsensitive)
        return regex
            .flatMap { $0.firstMatch(in: string, range: NSRange(location: 0, length: string.count)) }
            .flatMap { Range($0.range(at: 1), in: string) }
            .map { String(string[$0]) }
    }
}

/// Can build embed content asynchronously from Beam embed API
struct EmbedContentAPIStrategy: EmbedContentStrategy {

    enum EmbedContentAPIStrategyError: Error {
        case parsingCachedItem
    }

    private struct EmbedAPIResult: Codable {
        var url: String
        var title: String?
        var thumbnail: String?
        var html: String?
        var type: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: CodingKey {
            case url
            case title
            case thumbnail
            case html
            case type
            case item
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            if let cachedItemString = try? values.decode(String.self, forKey: .item) {
                guard let itemData = cachedItemString.data(using: .utf8) else {
                    throw EmbedContentAPIStrategyError.parsingCachedItem
                }
                let cachedItem = try JSONDecoder().decode(EmbedAPIResult.self, from: itemData)
                // for now api returns cached item wrapped in another object
                url = cachedItem.url
                title = cachedItem.title
                thumbnail = cachedItem.thumbnail
                html = cachedItem.html
                type = cachedItem.type
            } else {
                url = try values.decode(String.self, forKey: .url)
                title = try? values.decode(String.self, forKey: .title)
                thumbnail = try? values.decode(String.self, forKey: .thumbnail)
                html = try? values.decode(String.self, forKey: .html)
                type = try? values.decode(String.self, forKey: .type)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(url, forKey: .url)
            try? container.encode(title, forKey: .title)
            try? container.encode(thumbnail, forKey: .thumbnail)
            try? container.encode(html, forKey: .html)
            try? container.encode(type, forKey: .type)
        }
    }

    private let domainsSupportedByAPI = [
        "youtube.com", "youtu.be", "twitter.com", "instagram.com", "slideshare.net", "figma.com"
    ]
    /// *Potential* embed, doesn't mean it's 100% sure we will be able to build a embed
    func canBuildEmbeddableContent(for url: URL) -> Bool {
        guard let host = url.host else { return false }
        return domainsSupportedByAPI.contains { host.contains($0) }
    }

    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void) {
        let apiServer = RestAPIServer()
        let request = RestAPIServer.Request.embed(url: url)
        apiServer.request(serverRequest: request) { (result: Result<[EmbedAPIResult], Error>) in
            var error: EmbedContentError?
            var embedContent: EmbedContent?
            switch result {
            case .failure(_):
                error = .notEmbeddable
            case .success(let results):
                if let firstResult = results.first, let content = embedAPIResultToContent(firstResult, sourceURL: url) {
                    embedContent = content
                } else {
                    error = .notEmbeddable
                }
            }
            completion(embedContent, error)
        }
    }

    private func embedAPIResultToContent(_ apiResult: EmbedAPIResult, sourceURL: URL) -> EmbedContent? {
        let urlString = apiResult.url
        let url = URL(string: urlString)
        if apiResult.type == "image", let thumbnailString = apiResult.thumbnail, let imageURL = URL(string: thumbnailString) ?? url {
            return EmbedContent(sourceURL: sourceURL, type: .image, embedURL: imageURL)
        } else if let html = apiResult.html {
            return EmbedContent(sourceURL: sourceURL, type: .page, embedContent: html)
        } else if let url = url {
            return EmbedContent(sourceURL: sourceURL, type: .url, embedURL: url)
        }
        return nil
    }
}
