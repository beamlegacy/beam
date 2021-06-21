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

    fileprivate func isVideoUrl(_ url: String) -> Bool {
        let containsYouTube = url.contains("youtube.com")
        return containsYouTube
    }

    fileprivate func hasVideoIframe(_ html: String) -> Bool {
        guard let iframeSrc = html.slice(from: "src=\"", to: "\" ") else { return false }
        let isIframe = html.hasPrefix("<iframe")
        let isVideoSrc = isVideoUrl(iframeSrc)
        return isIframe && isVideoSrc
    }

    func isVideo(url: String, html: String) -> Bool {
        let hostContainsYoutube = isVideoUrl(url)
        let htmlHasVideoElement = html.hasPrefix("<video")
        let hasVideoIframeElment = hasVideoIframe(html)
        return hostContainsYoutube || htmlHasVideoElement || hasVideoIframeElment
    }

    func isImage(html: String) -> Bool {
        let htmlHasImgElement = html.starts(with: "<img")
        return htmlHasImgElement
    }

    func trim(url: String, html: String) -> String? {
        guard !isVideo(url: url, html: html), !isImage(html: html) else {
            return html
        }

        if let url = URL(string: url) {
            let text: BeamText = html2Text(url: url, html: html)
            if text.text.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                return html.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
