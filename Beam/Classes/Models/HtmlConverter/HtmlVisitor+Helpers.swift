//
//  HtmlVisitor+Helpers.swift
//  Beam
//
//  Created by Stef Kors on 15/12/2021.
//

import Foundation
import BeamCore
import SwiftSoup
import Swime

extension HtmlVisitor {
    enum HtmlVisitorError: Error {
        case imageDownloadFailed
    }

    static func storeImageData(_ data: Data, _ mimeType: String, _ name: String, _ fileStorage: BeamFileStorage) -> UUID? {
        return try? fileStorage.insert(name: name, data: data, type: mimeType)
    }

    /// Check if element is a default block level element.
    /// Based on this MDN list: https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements
    /// - Parameter element: SwiftSoup.Element
    /// - Returns: Boolean, true if block element
    func isDefaultBlockLevelElement(_ element: SwiftSoup.Element) -> Bool {
        let blockElments = [
            "address", "article", "aside",
            "blockquote",
            "details", "dialog",
            "dd", "div", "dl", "dt",
            "fieldset", "figcaption", "figure", "footer", "form",
            "h1", "h2", "h3", "h4", "h5", "h6",
            "header", "hgroup", "hr",
            "li",
            "main",
            "nav",
            "ol",
            "p", "pre",
            "section",
            "table",
            "ul"
        ]

        return blockElments.contains(element.tagName())
    }

    func getUrl(_ src: String) -> String {
        if let u = URL(string: src), u.host != nil {
            return u.absoluteString.markdownizedURL!
        }

        if let u = URL(string: src, relativeTo: urlBase), u.host != nil {
            return u.absoluteString.markdownizedURL!
        }

        return src
    }

    /// Gets a base64 image from a src string
    /// `data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAoGCBYTExcVFRUYGBcZGxsaGhoaG....`
    /// - Parameter src: full data src string
    /// - Returns: returns base64 string and mimeType, returns nil if data can't be parsed correctly
    func getBase64(_ src: String) -> (base64: Data, mimeType: String)? {
        let array = src.split(separator: ",").map(String.init)
        guard array.count == 2,
              let firstItem = array.first,
              let secondItem = array.last,
              let base64 = Data(base64Encoded: secondItem) else {
                  return nil
              }

        let mimeType = firstItem.replacingOccurrences(of: "data:", with: "", options: [.anchored])
        return (base64, mimeType)
    }

    /// Parses urls from a String to URL object. Handles converting relative urls to absolute urls. Allows for `file://` schemes.
    /// - Parameter src: string to parse
    /// - Returns: Full absolute url as URL object
    func getUrl(_ src: String) -> URL? {
        // get url from src string
        guard var url: URL = URL(string: src) else {
            return nil
        }
        // If we don't have a url host we are dealing with a relative url
        // that should be converted into an absolute url
        if url.host == nil,
           let absoluteUrl = URL(string: src, relativeTo: urlBase) {
            // Create a full url relative to the urlBase
            url = absoluteUrl
        }

        // continue only with urls that have a host or file scheme
        if url.host != nil || url.scheme == "file" {
            guard url.scheme == nil else {
                return url
            }
            // If we don't have a url scheme at all create one from the urlBase scheme
            if let scheme = urlBase.scheme,
               let newUrl = URL(string: scheme + ":" + url.absoluteString) {
                return newUrl
            }
        }

        return nil
    }

    /// Gets the `src` of an iframe element
    /// - Parameter element: iframe element
    /// - Returns: src string or nil
    func getIframeSrc(_ element: Element) -> String? {
        if let src = try? element.attr("src") {
            return src
        }

        return nil
    }

    /// Gets the `src` of an image element
    /// - Parameter element: image element
    /// - Returns: src string or nil
    func getImageAttributes(_ element: Element) -> (src: String?, size: CGSize?) {
        if let src = try? element.attr("src") {
            var size: CGSize?
            if let widthStr = try? element.attr("width"),
               let width = Int(widthStr),
               let heightStr = try? element.attr("height"),
               let height = Int(heightStr) {
                size = CGSize(width: width, height: height)
            }
            return (src, size)
        }

        return (nil, nil)
    }

    /// Gets the `src` of an video element. Supports video elements without `src` attribute that does have children with a `src` tag containing an mp4.
    /// - Parameter element: video element
    /// - Returns: src string or nil
    func getVideoSrc(_ element: Element) -> String? {
        if let src = try? element.attr("src"),
           src.count > 0 {
            // TODO: remove this when we can rely on oembed for url conversion
            // Use the page url because youtube <video> src's aren't convertable to /embed/ urls
            if src.hasPrefix("blob:") {
                return urlBase.absoluteString
            }
            return src
        }

        // If no src on element try any of the children
        // For the children specifically grabs the `.mp4` file.
        if let childrenWithSource = try? element.getElementsByAttribute("src") {
            let childUrls = childrenWithSource.compactMap({ child in
                return getVideoSrc(child)
            })

            // If we have any urls containing .mp4 type, return that one
            if let mp4url = childUrls.first(where: { $0.contains(".mp4") }) {
                return mp4url
            } else {
                // else return any valid video src
                return childUrls.first
            }
        }

        return nil
    }

    static func imageSize(data: Data, type: String, htmlSize: CGSize?) -> CGSize? {
        switch type {
        case "image/svg+xml":
            return htmlSize
        default:
            guard let image = NSImage(data: data), let rep = image.representations.first else {
                Logger.shared.logError("Unable to get image size from an image of type \(type) using NSImage", category: .pointAndShoot)
                return htmlSize
            }
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
    }
}
