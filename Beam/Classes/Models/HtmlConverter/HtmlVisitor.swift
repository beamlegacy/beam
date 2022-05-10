//
//  HtmlVisitor.swift
//  Beam
//
//  Created by Stef Kors on 06/09/2021.
//
// swiftlint:disable file_length

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
    static var allowConvertToEmbed: Bool {
        PreferencesManager.embedContentPreference == PreferencesEmbedOptions.always.id ||
            PreferencesManager.embedContentPreference == PreferencesEmbedOptions.only.id
    }

    private var embedURLs: Set<URL> = []

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
                // fallthrough when no child elements or no text
                guard !childElements.isEmpty || element.hasText() else {
                    fallthrough
                }

                let children = childElements.map({ child -> BeamElement in
                    // Trim whitespace from links
                    child.text = child.text.trimming(.whitespaces)
                    // convert href of element into a link
                    guard let href = try? element.attr("href") else {
                        return child
                    }
                    let url: String = getUrl(href)
                    child.text.addAttributes([.link(url)], to: child.text.wholeRange)

                    // Only try to convert to embed if it's text content
                    if child.kind.isText {
                        return convertElementToEmbed(child)
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

            case "svg":
                let fileName = UUID().uuidString
                let mimeType = "image/svg+xml"
                // Get size from svg element
                var size: CGSize = .zero
                if let widthStr = try? element.attr("width"),
                   let width = Int(widthStr),
                   let heightStr = try? element.attr("height"),
                   let height = Int(heightStr) {
                    size = CGSize(width: width, height: height)
                }

                if let svgData = try? element.html().asData,
                   let fileStorage = fileStorage,
                   let fileId = HtmlVisitor.storeImageData(svgData, mimeType, fileName, fileStorage) {
                    let imgElement = BeamElement()
                    imgElement.kind = .image(
                        fileId,
                        origin: SourceMetadata(origin: .remote(self.urlBase)),
                        displayInfos: MediaDisplayInfos(
                            height: Int(size.height),
                            width: Int(size.width),
                            displayRatio: nil
                        )
                    )

                    text.append(imgElement)
                }

            case "iframe":
                guard let src = getImageAttributes(element).src,
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let iframeElement = BeamElement(mdUrl)
                iframeElement.text.addAttributes([.link(mdUrl)], to: iframeElement.text.wholeRange)
                text.append(convertElementToEmbed(iframeElement))

            case "video":
                guard let src = getVideoSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let embedElement = BeamElement(mdUrl)
                embedElement.text.addAttributes([.link(mdUrl)], to: embedElement.text.wholeRange)
                text.append(convertElementToEmbed(embedElement))

            case "br":
                text.append(BeamElement(" "))

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
                // only append string if it's non empty
                if !string.trimmingCharacters(in: .whitespaces).isEmpty {
                    text.append(BeamElement(string))
                }
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

    private func embeddableURL(_ element: BeamElement) -> URL? {
        let links = element.text.links
        guard HtmlVisitor.allowConvertToEmbed,
              links.count == 1,
              let link = links.first,
              let url = URL(string: link),
              EmbedContentBuilder().canBuildEmbed(for: url),
              // Use the Embed Provider matcher to cleanup the embed url
              let embedUrl = EmbedContentBuilder().embedMatchURL(for: url) else {
            return nil
        }

        return embedUrl
    }

    /// Utility to convert BeamElement containing a single embedable url to embed kind
    private func convertElementToEmbed(_ element: BeamElement) -> BeamElement {
        guard let embedUrl = embeddableURL(element) else { return element }
        // If the embed was already created earlier, return early
        let embedWasPreviouslyAdded = embedURLs.contains(embedUrl)
        guard !embedWasPreviouslyAdded else { return BeamElement() }
        // Add cleaned up embed url to the set to avoid duplicated embed elements
        embedURLs.insert(embedUrl)
        // Convert to embed
        element.kind = .embed(
            embedUrl,
            origin: SourceMetadata(origin: .remote(self.urlBase)),
            displayInfos: MediaDisplayInfos()
        )

        // Embed elements should not have children
        element.children.removeAll()

        return element
    }
}
