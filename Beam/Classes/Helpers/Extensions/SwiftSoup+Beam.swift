//
//  SwiftSoup+Beam.swift
//  Beam
//
//  Created by Stef Kors on 06/09/2021.
//

import Foundation
import SwiftSoup
import BeamCore

extension SwiftSoup.Document {
    func extractLinks() -> [String] {
        do {
            //Logger.shared.logInfo("html -> \(html)")
            let els: Elements = try select("a")

            // capture all the links containted in the page:
            return try els.array().map { element -> String in
                try element.absUrl("href")
            }
        } catch Exception.Error(let type, let message) {
            Logger.shared.logError("PageRank (SwiftSoup parser) \(type): \(message)", category: .web)
        } catch {
            Logger.shared.logError("PageRank: (SwiftSoup parser) unkonwn error", category: .web)
        }

        return []
    }
}
