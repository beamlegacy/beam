//
//  PointAndShoot+Text2Quote.swift
//  Beam
//
//  Created by Stef Kors on 02/07/2021.
//

import Foundation
import BeamCore
import Promises

enum Text2QuoteError: Error {
    case imageDownloadFailed
}

extension Text2QuoteError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .imageDownloadFailed:
            return NSLocalizedString("Image download failed", comment: "Image might be empty or invalid")
        }
    }
}

extension PointAndShoot {
    /// Convert BeamText to quote BeamElement. Takes care of converting video links to embeds and converting + downloading image links
    /// - Parameters:
    ///   - text: BeamText to convert
    ///   - href: Page URL
    /// - Returns: BeamElement of quote kind
    func text2Quote(_ text: BeamText, _ href: String) -> Promise<BeamElement> {
        var mutableText = text
        mutableText.addAttributes([.emphasis], to: text.wholeRange)
        let quote = BeamElement(mutableText)
        quote.query = self.page.originalQuery
        quote.kind = .quote(1, self.page.title, href)
        if PreferencesManager.embedContentPreference == EmbedContent.always.id ||
            PreferencesManager.embedContentPreference == EmbedContent.only.id {
            quote.convertToEmbed() // if possible converts url to embed
        }
        // If quote is image, download and convert quote to image kind
        if let src = quote.imageLink,
           let downloadManager = self.page.downloadManager {
            let fileStorage = self.page.fileStorage
            return Promise<BeamElement> { fulfill, reject in
                return downloadManager.downloadImage(src, pageUrl: self.page.url ?? src, completion: { result in
                    do {
                        guard let (data, mimeType) = result else {
                            throw Text2QuoteError.imageDownloadFailed
                        }

                        let fileId = data.MD5
                        try fileStorage?.insert(name: src.lastPathComponent, uid: fileId, data: data, type: mimeType)
                        quote.convertToImage(fileId)
                        fulfill(quote)
                    } catch let error {
                        reject(error)
                    }
                })
            }
        } else {
            return Promise(quote)
        }
    }

    /// Convert array of BeamTexts with `text2Quote`.
    /// - Parameters:
    ///   - text: BeamText to convert
    ///   - href: Page URL
    /// - Returns: BeamElement of quote kind
    func text2Quote(_ texts: [BeamText], _ href: String) -> Promise<[BeamElement]> {
        return all(texts.compactMap({ text -> Promise<BeamElement> in
            return text2Quote(text, href)
        })).catch({ error in
            Logger.shared.logError("Failed to convert text2Quote: \(error.localizedDescription)", category: .pointAndShoot)
        })
    }
}
