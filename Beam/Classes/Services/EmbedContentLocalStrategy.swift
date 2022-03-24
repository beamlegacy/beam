//
//  EmbedContentLocalStrategy.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation

/// Can build embed content from local synchronous parsing
struct EmbedContentLocalStrategy: EmbedContentStrategy {
    func embedMatchURL(for url: URL) -> URL? {
        var embedUrl: URL?
        embeddableContent(for: url) { embedContent, _ in
            if let url = embedContent?.embedURL {
                embedUrl = url
            }
        }
        return embedUrl
    }

    func canBuildEmbeddableContent(for url: URL) -> Bool {
        var canEmbed = false
        embeddableContent(for: url) { embedContent, _ in
            canEmbed = embedContent != nil
        }
        return canEmbed
    }

    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void) {
        // If url is already youtube/embed/ 
        if url.path.contains("/embed/"), url.mainHost == "youtube.com" {
            let result = EmbedContent(title: url.absoluteString, type: .link, sourceURL: url, embedURL: url)
            completion(result, nil)
            return
        }

        completion(nil, .notEmbeddable)
    }
}
