//
//  QuoteCleanup.swift
//  Beam
//
//  Created by Stef Kors on 03/06/2021.
//

import Foundation
import BeamCore
import SwiftSoup
import Promises

class Quote {
    let parseHtml: ParseHtml = ParseHtml()

    func getQuoteKind(html: String, page: WebPage, group: PointAndShoot.ShootGroup) -> Promise<ElementKind> {
        return Promise { fulfill, _ in
            guard let url = URL(string: group.href) else {
                fatalError("Expected to have Page URL")
            }
            if self.parseHtml.isVideo(url: url.absoluteString, html: html) {
                return fulfill(.embed(url.absoluteString))
            }
            if self.parseHtml.isImage(html: html) {
                let doc = try SwiftSoup.parseBodyFragment(html)
                let img = try doc.select("img")[0]
                let downloadManager = page.downloadManager
                let fileStorage = page.fileStorage
                self.imageQuoteKind(imageEl: img, referer: url, downloadManager: downloadManager, fileStorage: fileStorage).then { quoteKind in
                    return fulfill(quoteKind)
                }
                return
            }
            fulfill(.quote(1, page.title, url.absoluteString))
        }
    }

    func imageQuoteKind(imageEl: Element, referer: URL, downloadManager: DownloadManager, fileStorage: BeamFileStorage) -> Promise<ElementKind> {
        return Promise { fulfill, reject in
            let url = try imageEl.attr("src")
            let absoluteUrl = try self.parseHtml.helpers.getAbsoluteUrl(url: url, refererUrl: referer)

            return downloadManager.downloadURL(absoluteUrl, headers: ["Referer": referer.string], completion: { result -> Void in
                var fileId: String

                guard case .binary(let data, let mimeType, _) = result else {
                    reject(PointAndShootError("Retrieved data when downloading \(absoluteUrl) is not binary"))
                    return
                }

                guard data.count > 0 else {
                    reject(PointAndShootError("No data was retrieved when downloading \(absoluteUrl)"))
                    return
                }

                fileId = data.MD5
                do {
                    try fileStorage.insert(name: absoluteUrl.lastPathComponent, uid: fileId, data: data, type: mimeType)
                } catch let error {
                    reject(error)
                    return
                }

                let kind: ElementKind = .image(fileId)
                fulfill(kind)
            })
        }
    }
}
