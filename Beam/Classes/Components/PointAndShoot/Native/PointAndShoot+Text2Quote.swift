//
//  PointAndShoot+Text2Quote.swift
//  Beam
//
//  Created by Stef Kors on 02/07/2021.
//

import Foundation
import BeamCore
import Promises

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
        quote.convertToEmbed() // if possible converts url to embed
        // If quote is image, download and convert quote to image kind
        if let src = quote.imageLink {
            let fileStorage = self.page.fileStorage
            let downloadImage = self.page.downloadManager.downloadImage
            return Promise<BeamElement> { fulfill, reject in
                downloadImage(src, self.page.url ?? src, { result in
                    do {
                        if let (data, mimeType) = result {
                            let fileId = data.MD5
                            try fileStorage.insert(name: src.lastPathComponent, uid: fileId, data: data, type: mimeType)
                            quote.convertToImage(fileId)
                            fulfill(quote)
                        }
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
