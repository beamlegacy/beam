//
//  EmbedContentStrategy.swift
//  Beam
//
//  Created by Stef Kors on 03/12/2021.
//

import Foundation

// MARK: - Strategies
protocol EmbedContentStrategy {
    func canBuildEmbeddableContent(for url: URL) -> Bool
    func embeddableContent(for url: URL, completion: @escaping (EmbedContent?, EmbedContentError?) -> Void)
}
