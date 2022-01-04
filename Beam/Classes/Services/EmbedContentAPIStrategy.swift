//
//  EmbedContentAPIStrategy.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation
import BeamCore

/// Can build embed content asynchronously from Beam embed API
struct EmbedContentAPIStrategy: EmbedContentStrategy {

    init() {
        SupportedEmbedDomains.shared.updateDomainsSupportedByAPI()
    }

    enum EmbedContentAPIStrategyError: Error {
        case parsingCachedItem
    }

    private struct EmbedAPIResult: Codable {
        var url: String
        var title: String
        var thumbnail: String?
        var html: String?
        var type: String?
        var width: CGFloat?
        var height: CGFloat?
        var minWidth: CGFloat?
        var maxWidth: CGFloat?
        var minHeight: CGFloat?
        var maxHeight: CGFloat?
        var keepAspectRatio: Bool?
        var responsive: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: CodingKey {
            case url
            case title
            case thumbnail
            case html
            case type
            case item
            case width
            case height
            case minWidth
            case maxWidth
            case minHeight
            case maxHeight
            case keepAspectRatio
            case responsive
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
                width = cachedItem.width
                height = cachedItem.height
                minWidth = cachedItem.minWidth
                maxWidth = cachedItem.maxWidth
                minHeight = cachedItem.minHeight
                maxHeight = cachedItem.maxHeight
                keepAspectRatio = cachedItem.keepAspectRatio
                responsive = cachedItem.responsive
            } else {
                url = try values.decode(String.self, forKey: .url)
                title = try values.decode(String.self, forKey: .title)
                thumbnail = try? values.decode(String.self, forKey: .thumbnail)
                html = try? values.decode(String.self, forKey: .html)
                type = try? values.decode(String.self, forKey: .type)
                width = try? values.decode(CGFloat.self, forKey: .width)
                height = try? values.decode(CGFloat.self, forKey: .height)
                minWidth = try? values.decode(CGFloat.self, forKey: .minWidth)
                maxWidth = try? values.decode(CGFloat.self, forKey: .maxWidth)
                minHeight = try? values.decode(CGFloat.self, forKey: .minHeight)
                maxHeight = try? values.decode(CGFloat.self, forKey: .maxHeight)
                keepAspectRatio = try? values.decode(Bool.self, forKey: .keepAspectRatio)
                responsive = try? values.decode(String.self, forKey: .responsive)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(url, forKey: .url)
            try? container.encode(title, forKey: .title)
            try? container.encode(thumbnail, forKey: .thumbnail)
            try? container.encode(html, forKey: .html)
            try? container.encode(type, forKey: .type)
            try? container.encode(width, forKey: .width)
            try? container.encode(height, forKey: .height)
            try? container.encode(minWidth, forKey: .minWidth)
            try? container.encode(maxWidth, forKey: .maxWidth)
            try? container.encode(minHeight, forKey: .minHeight)
            try? container.encode(maxHeight, forKey: .maxHeight)
            try? container.encode(keepAspectRatio, forKey: .keepAspectRatio)
            try? container.encode(responsive, forKey: .responsive)
        }
    }
    /// *Potential* embed, doesn't mean it's 100% sure we will be able to build a embed
    func canBuildEmbeddableContent(for url: URL) -> Bool {
        let pattern = SupportedEmbedDomains.shared.pattern
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(location: 0, length: url.absoluteString.count)
        let matches = regex.matches(in: url.absoluteString, options: [], range: range)
        return !matches.isEmpty
    }

    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void) {
        let apiServer = RestAPIServer()
        let request = RestAPIServer.Request.embed(url: url)
        apiServer.request(serverRequest: request) { (result: Result<[EmbedAPIResult], Error>) in
            var error: EmbedContentError?
            var embedContent: EmbedContent?
            switch result {
                // swiftlint:disable:next empty_enum_arguments
            case .failure(_):
                error = .notEmbeddable
            case .success(let results):
                if let firstResult = results.first, let content = self.embedAPIResultToContent(firstResult, sourceURL: url) {
                    embedContent = content
                } else {
                    error = .notEmbeddable
                }
            }
            completion(embedContent, error)
        }
    }

    private func getThumbnailURL(url: String?) -> URL? {
        guard let url = url,
              let imageUrl = URL(string: url) else {
                  return nil
              }
        return imageUrl
    }

    private func embedAPIResultToContent(_ apiResult: EmbedAPIResult, sourceURL: URL) -> EmbedContent? {
        let title = apiResult.title

        guard let mediaRawType = apiResult.type,
              let typeEnum = EmbedContent.MediaType(rawValue: mediaRawType),
              let responsiveRawType = apiResult.responsive,
              let responsive = ResponsiveType(rawValue: responsiveRawType),
              let url = URL(string: apiResult.url) else {
                  if let url = URL(string: apiResult.url) {
                      // if we have no matching MediaType, for example when `apiResult.type` is `text/html`, default to MediaType.url
                      return EmbedContent(title: apiResult.title, type: .link, sourceURL: sourceURL, embedURL: url)
                  }
                  return nil
              }

        let thumbnail = getThumbnailURL(url: apiResult.thumbnail) ?? url
        let aspectRatio = apiResult.keepAspectRatio ?? true
        let embed = EmbedContent(
            title: title,
            type: typeEnum,
            sourceURL: sourceURL,
            embedURL: url,
            html: apiResult.html,
            thumbnail: thumbnail,
            width: apiResult.width,
            height: apiResult.height,
            minWidth: apiResult.minWidth,
            maxWidth: apiResult.maxWidth,
            minHeight: apiResult.minHeight,
            maxHeight: apiResult.maxHeight,
            keepAspectRatio: aspectRatio,
            responsive: responsive
        )
        return embed
    }
}
