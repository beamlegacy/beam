//
//  Html.swift
//  Beam
//
//  Created by Stef Kors on 03/06/2021.
//

import Foundation
import BeamCore

class ParseHtml {
    let helpers: Helpers = Helpers()
    class Helpers {
        func getAbsoluteUrl(url: String, refererUrl: URL) throws -> URL {
            guard let imageUrl = URL(string: url) else {
                throw PointAndShootError("\(url) is not a valid URL")
            }

            if imageUrl.scheme != nil {
                return imageUrl
            }

            return try getRefererUrl(url: url, refererUrl: refererUrl)
        }

        func getRefererUrl(url: String, refererUrl: URL) throws -> URL {
            guard let referredURL = URL(string: url, relativeTo: refererUrl) else {
                throw PointAndShootError("Cannot build a valid URL from \(url) based on \(refererUrl.string)")
            }
            return referredURL
        }
    }

    func isVideo(url: URL, html: String) -> Bool {
        guard let host = url.host else { return false }

        let hostContainsYoutube = ["www.youtube.com", "youtube.com"].contains(host)
        let htmlHasVideoElement = html.hasPrefix("<video")

        return hostContainsYoutube || htmlHasVideoElement
    }

    func isImage(html: String) -> Bool {
        let htmlHasImgElement = html.starts(with: "<img")

        return htmlHasImgElement
    }

    func trim(url: URL, html: String) -> String? {
        guard !isVideo(url: url, html: html), !isImage(html: html) else {
            return html
        }

        let text: BeamText = html2Text(url: url, html: html)
        if text.text.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
            return html.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
