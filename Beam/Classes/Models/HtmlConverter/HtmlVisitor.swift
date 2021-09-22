//
//  HtmlVisitor.swift
//  Beam
//
//  Created by Stef Kors on 06/09/2021.
//

import Foundation
import SwiftSoup
import BeamCore

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
        PreferencesManager.embedContentPreference == EmbedContent.always.id ||
            PreferencesManager.embedContentPreference == EmbedContent.only.id
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
    func parse(_ document: SwiftSoup.Node) -> [BeamElement] {
        let elements: [BeamElement] = visit(document)
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            // Call closure to download
            for delayedClosure in delayedClosures {
                if let downloadManager = downloadManager {
                    downloadManager.downloadImage(delayedClosure.url, pageUrl: urlBase, completion: delayedClosure.closure)
                }
            }
            delayedClosures.removeAll()
        }

        return elements
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
                        child.convertToEmbed() // if possible converts url to embed
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
                guard let src = getImageSrc(element) else { break }
                // has ImageSRC
                if let url: URL = getUrl(src),
                   url.isImageURL {
                    let mdUrl = url.absoluteString
                    let imgElement = BeamElement(mdUrl)
                    let fileName = url.lastPathComponent

                    // By defining the Closure outside the `visit()` func we keep the reference to the imgElement
                    // With this in memory reference we can close the closure without having to wrap
                    // everything in closures

                    if let fileStorage = fileStorage {
                        let closure: ((data: Data, mimeType: String)?) -> Void = { result in
                            guard let (data, mimeType) = result,
                                  let fileId = Self.storeImageData(data, mimeType, fileName, fileStorage) else {
                                imgElement.text.addAttributes([.link(mdUrl)], to: imgElement.text.wholeRange)
                                return
                            }
                            imgElement.kind = .image(fileId)
                        }
                        let object = DelayedClosure(closure: closure, url: url)
                        delayedClosures.append(object)
                    }

                    text.append(imgElement)

                    // has base64 src
                } else if let (base64, mimeType) = getBase64(src) {
                    let fileName = UUID().uuidString
                    if let fileStorage = fileStorage,
                       let fileId = HtmlVisitor.storeImageData(base64, mimeType, fileName, fileStorage) {
                        let imgElement = BeamElement()
                        imgElement.kind = .image(fileId)
                        text.append(imgElement)
                    }
                }

            case "iframe":
                guard let src = getImageSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let iframeElement = BeamElement(mdUrl)
                iframeElement.text.addAttributes([.link(mdUrl)], to: iframeElement.text.wholeRange)
                if allowConvertToEmbed {
                    iframeElement.convertToEmbed() // if possible converts url to embed
                }
                text.append(iframeElement)

            case "video":
                guard let src = getVideoSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let embedUrl = urlBase.embed ?? url.embed
                if let mdEmbedUrl = embedUrl?.absoluteString.markdownizedURL {
                    let embedElement = BeamElement(mdEmbedUrl)
                    embedElement.text.addAttributes([.link(mdEmbedUrl)], to: embedElement.text.wholeRange)
                    if allowConvertToEmbed {
                        embedElement.convertToEmbed() // if possible converts url to embed
                    }
                    text.append(embedElement)
                } else {
                    let urlElement = BeamElement(src)
                    urlElement.text.addAttributes([.link(mdUrl)], to: urlElement.text.wholeRange)
                    if allowConvertToEmbed {
                        urlElement.convertToEmbed() // if possible converts url to embed
                    }
                    text.append(urlElement)
                }

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
}

extension HtmlVisitor {
    enum HtmlVisitorError: Error {
        case imageDownloadFailed
    }

    static fileprivate func storeImageData(_ data: Data, _ mimeType: String, _ name: String, _ fileStorage: BeamFileStorage) -> UUID? {
        do {
            let fileId = UUID.v5(name: data.SHA256, namespace: .url)
            try fileStorage.insert(name: name, uid: fileId, data: data, type: mimeType)
            return fileId
        } catch let error {
            Logger.shared.logError("Error while downloading image: \(error)", category: .document)
        }

        return nil
    }

    /// Check if element is a default block level element.
    /// Based on this MDN list: https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements
    /// - Parameter element: SwiftSoup.Element
    /// - Returns: Boolean, true if block element
    func isDefaultBlockLevelElement(_ element: SwiftSoup.Element) -> Bool {
        let blockElments = [
            "address",
            "article",
            "aside",
            "blockquote",
            "details",
            "dialog",
            "dd",
            "div",
            "dl",
            "dt",
            "fieldset",
            "figcaption",
            "figure",
            "footer",
            "form",
            "h1",
            "h2",
            "h3",
            "h4",
            "h5",
            "h6",
            "header",
            "hgroup",
            "hr",
            "li",
            "main",
            "nav",
            "ol",
            "p",
            "pre",
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

    func getUrl(_ src: String) -> URL? {
        if let url = URL(string: src),
           (url.host != nil || url.scheme == "file") {
            if url.scheme != nil {
                return url
            }

            if let scheme = urlBase.scheme,
               let newUrl = URL(string: scheme + ":" + url.absoluteString) {
                return newUrl
            }
        }

        if let url = URL(string: src, relativeTo: urlBase),
           url.host != nil {
            return url
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
    func getImageSrc(_ element: Element) -> String? {
        if let src = try? element.attr("src") {
            return src
        }

        return nil
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
            return childrenWithSource.compactMap({ child in
                return getVideoSrc(child)
            }).filter({ $0.contains(".mp4") }).first
        }

        return nil
    }
}
