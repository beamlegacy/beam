//
//  HtmlVisitor.swift
//  Beam
//
//  Created by Stef Kors on 06/09/2021.
//

import Foundation
import SwiftSoup
import BeamCore
import Swime

struct DelayedClosure {
    var closure: ((data: Data, mimeType: String)?) -> Void
    var url: URL
}

/// Recusively visit each document Node and parse them into BeamElements.
/// If both the `downloadManager` and `fileStorage` are provided supported assets
/// such as images are downloaded and stored on the fileStorage
class HtmlVisitor {
    // Depth of recursion
    var depth = 0
    // Url of where the html originates from
    var urlBase: URL
    // Optional DownloadManager
    var downloadManager: DownloadManager?
    // Optional fileStorage
    var fileStorage: BeamFileStorage?
    // Checks preferences to allow embedding of content
    var allowConvertToEmbed: Bool {
        PreferencesManager.embedContentPreference == PreferencesEmbedOptions.always.id ||
            PreferencesManager.embedContentPreference == PreferencesEmbedOptions.only.id
    }

    var delayedClosures: [DelayedClosure] = []

    init(_ urlBase: URL, _ downloadManager: DownloadManager?, _ fileStorage: BeamFileStorage?) {
        self.urlBase = urlBase
        self.downloadManager = downloadManager
        self.fileStorage = fileStorage
    }

    /// visit and parse DOM Node and it's children.
    /// - Parameter document: SwiftSoup HTML node
    /// - Returns: Array of BeamElements
    func parse(_ document: SwiftSoup.Node, completion: @escaping ([BeamElement]) -> Void) {
        let elements: [BeamElement] = visit(document)
        // Call closure to download
        for delayedClosure in delayedClosures {
            if let downloadManager = downloadManager {
                downloadManager.downloadImage(delayedClosure.url, pageUrl: urlBase, completion: delayedClosure.closure)
            }
        }
        delayedClosures.removeAll()
        completion(elements)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func visit(_ node: SwiftSoup.Node) -> [BeamElement] {
        var text: [BeamElement] = []
        if let element = node as? SwiftSoup.Element {
            switch element.tagName() {
            case "a":
                let childElements: [BeamElement] = visitChildren(element)
                let children = childElements.map({ child -> BeamElement in
                    // Trim whitespace from links
                    child.text = child.text.trimming(.whitespaces)
                    // convert href of element into a link
                    guard let href = try? element.attr("href") else {
                        return child
                    }
                    let url: String = getUrl(href)
                    child.text.addAttributes([.link(url)], to: child.text.wholeRange)
                    if allowConvertToEmbed {
                        convertElementToEmbed(child) // if possible converts url to embed
                    }
                    return child
                })

                text.append(contentsOf: children)

            case "span":
                let children: [BeamElement] = visitChildren(element)
                text.append(contentsOf: children)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "i": fallthrough

            case "em":
                var children: [BeamElement] = visitChildren(element)
                children = children.map({ child -> BeamElement in
                    child.text.addAttributes([.emphasis], to: child.text.wholeRange)
                    return child
                })
                text.append(contentsOf: children)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "b": fallthrough

            case "strong":
                var children: [BeamElement] = visitChildren(element)
                children = children.map({ child -> BeamElement in
                    child.text.addAttributes([.strong], to: child.text.wholeRange)
                    return child
                })
                text.append(contentsOf: children)

            case "img":
                let imgAttr = getImageAttributes(element)
                guard let src = imgAttr.src else { break }
                // We assume that any url used as <img src="..." /> is a valid image.
                // If the closure fails to download an image it defaults to a plain link.
                if let url: URL = getUrl(src) {
                    let mdUrl = url.absoluteString
                    let imgElement = BeamElement(mdUrl)
                    let fileName = url.lastPathComponent
                    // BeamElements default to bullets, if we don't create an image kind here the closure
                    // will lose it's reference because it will be executed after joining BeamElement together
                    imgElement.kind = .image(UUID(), origin: SourceMetadata(origin: .remote(self.urlBase)), displayInfos: MediaDisplayInfos())

                    // By defining the Closure outside the `visit()` func we keep the reference to the imgElement
                    // With this in memory reference we can close the closure without having to wrap
                    // everything in closures

                    if let fileStorage = fileStorage {
                        let closure: ((data: Data, mimeType: String)?) -> Void = { [urlBase] result in
                            guard let (data, mimeType) = result,
                                  let fileId = Self.storeImageData(data, mimeType, fileName, fileStorage),
                                  let size = Self.imageSize(data: data, type: mimeType, htmlSize: imgAttr.size) else {
                                imgElement.text.addAttributes([.link(mdUrl)], to: imgElement.text.wholeRange)
                                return
                            }
                            imgElement.kind = .image(
                                fileId,
                                origin: SourceMetadata(origin: .remote(self.urlBase)),
                                displayInfos: MediaDisplayInfos(
                                    height: Int(size.height),
                                    width: Int(size.width),
                                    displayRatio: nil
                                )
                            )

                            // If we can get the image, change the text of the element to the actual source instead of the link
                            imgElement.text = BeamText(text: urlBase.absoluteString)
                        }
                        let object = DelayedClosure(closure: closure, url: url)
                        delayedClosures.append(object)
                    }

                    text.append(imgElement)

                    // has base64 src
                } else if let (base64, mimeType) = getBase64(src) {
                    let fileName = UUID().uuidString
                    if let fileStorage = fileStorage,
                       let fileId = HtmlVisitor.storeImageData(base64, mimeType, fileName, fileStorage),
                       let size = Self.imageSize(data: base64, type: mimeType, htmlSize: imgAttr.size) {
                        let imgElement = BeamElement()
                        imgElement.kind = .image(fileId, origin: SourceMetadata(origin: .remote(self.urlBase)), displayInfos: MediaDisplayInfos(height: Int(size.height), width: Int(size.width), displayRatio: nil))

                        // If we can get the image, change the text of the element to the actual source instead of the link
                        imgElement.text = BeamText(text: urlBase.absoluteString)

                        text.append(imgElement)
                    }
                }

            case "iframe":
                guard let src = getImageAttributes(element).src,
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let iframeElement = BeamElement(mdUrl)
                iframeElement.text.addAttributes([.link(mdUrl)], to: iframeElement.text.wholeRange)
                if allowConvertToEmbed {
                    convertElementToEmbed(iframeElement) // if possible converts url to embed
                }
                text.append(iframeElement)

            case "video":
                guard let src = getVideoSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let embedElement = BeamElement(mdUrl)
                embedElement.text.addAttributes([.link(mdUrl)], to: embedElement.text.wholeRange)
                if allowConvertToEmbed {
                    convertElementToEmbed(embedElement) // if possible converts url to embed
                }
                text.append(embedElement)

            default:
                let children: [BeamElement] = visitChildren(element)
                text.append(contentsOf: children)
                if isDefaultBlockLevelElement(element) {
                    text.append(BeamElement("\n"))
                }
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let string = textNode.text().components(separatedBy: CharacterSet.controlCharacters).joined()
                text.append(BeamElement(string))
            }
            let children: [BeamElement] = visitChildren(node)
            text.append(contentsOf: children)
        }

        return text
    }

    private func visitChildren(_ node: SwiftSoup.Node) -> [BeamElement] {
        guard node.childNodeSize() != 0 else { return [] }
        depth += 1
        var result: [BeamElement] = []
        for child in node.getChildNodes() {
            let res: [BeamElement] = visit(child)
            result.append(contentsOf: res)
        }
        depth -= 1

        return result
    }

    /// Utility to convert BeamElement containing a single embedable url to embed kind
    private func convertElementToEmbed(_ element: BeamElement) {
        let links = element.text.links
        if links.count == 1,
           let link = links.first,
           let url = URL(string: link),
           EmbedContentBuilder().canBuildEmbed(for: url) {
            element.kind = .embed(url, origin: SourceMetadata(origin: .remote(self.urlBase)), displayRatio: nil)
        }
    }
}

extension HtmlVisitor {
    enum HtmlVisitorError: Error {
        case imageDownloadFailed
    }

    static fileprivate func storeImageData(_ data: Data, _ mimeType: String, _ name: String, _ fileStorage: BeamFileStorage) -> UUID? {
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

    private static func imageSize(data: Data, type: String, htmlSize: CGSize?) -> CGSize? {
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
