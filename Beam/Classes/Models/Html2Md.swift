//
//  Html2Md.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation
import SwiftSoup
import BeamCore
import Promises

class HtmlVisitor {
    var depth = 0
    var tabs: String { String.tabs(depth) }
    var urlBase: URL
    var keepFormatting: Bool = false
    var data: BeamData?

    init(_ urlBase: URL) {
        self.urlBase = urlBase
    }

    var debug = false

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visitMD(_ node: SwiftSoup.Node) -> String {
        var text = ""
        if let element = node as? SwiftSoup.Element {
            do {
                switch element.tagName() {
                case "a":
                    let href = try element.attr("href")
                    let url: String = {
                        if let u = URL(string: href), u.host != nil {
                            return u.absoluteString.markdownizedURL!
                        }

                        if let u = URL(string: href, relativeTo: urlBase), u.host != nil {
                            return u.absoluteString.markdownizedURL!
                        }

                        return href.markdownizedURL!
                    }()
                    if debug { Logger.shared.logInfo(tabs + "a href = '\(href)'", category: .document) }
                    text += "["
                    let title = visitChildrenMD(element).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    text += title
                    text += "](\(url))"
                case "span":
                    if debug { Logger.shared.logInfo(tabs + "span...", category: .document) }
                    text += visitChildrenMD(element)

                // swiftlint:disable:next fallthrough no_fallthrough_only
                case "i": fallthrough
                case "em":
                    if debug { Logger.shared.logInfo(tabs + "em...", category: .document) }
                    let contents = visitChildrenMD(element)
                    if keepFormatting {
                        text += "_**" + contents + "**_"
                    } else {
                        text += contents
                    }

                // swiftlint:disable:next fallthrough no_fallthrough_only
                case "b": fallthrough
                case "strong":
                    if debug { Logger.shared.logInfo(tabs + "strong...", category: .document) }
                    let contents = visitChildrenMD(element)
                    if keepFormatting {
                        text += "**" + contents + "**"
                    } else {
                        text += contents
                    }

                default:
                    text += visitChildrenMD(node)
                }
            } catch Exception.Error(let type, let message) {
                Logger.shared.logError("\(type): \(message)", category: .document)
            } catch {
                Logger.shared.logError("HtmlVisitor: error", category: .document)
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let t = textNode.text()
                if debug { Logger.shared.logInfo(tabs + "textNode = '\(t)'", category: .document) }

                text += t
            } else {
                if debug { Logger.shared.logInfo(tabs + "??? node ??? = '\(node)'", category: .document) }
            }

            text += visitChildrenMD(node)
        }

        if depth == 0 {
            if debug { Logger.shared.logInfo("html2Md -> '\(text)'", category: .document) }
            return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        return text
    }

    func visitChildrenMD(_ node: SwiftSoup.Node) -> String {
        guard node.childNodeSize() != 0 else { return "" }
        depth += 1
        let result = node.getChildNodes().reduce("") { previous, node -> String in
            previous + visitMD(node)
        }
        depth -= 1

        return result
    }

    // Text Version:
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visit(_ node: SwiftSoup.Node) -> String {
        var text = ""
        if let element = node as? SwiftSoup.Element {
            switch element.tagName() {
            case "a":
                let title = visitChildren(element).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                text += title
            case "span":
                if debug { Logger.shared.logInfo(tabs + "span...", category: .document) }
                text += visitChildren(element)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "i": fallthrough
            case "em":
                let contents: String = visitChildren(element)
                text += contents

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "b": fallthrough
            case "strong":
                let contents: String = visitChildren(element)
                text += contents

            default:
                text += visitChildren(node) + "\n"
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let t = textNode.text()
                text += t
            }
            text += visitChildren(node)
        }

        if depth == 0 {
            if debug { Logger.shared.logInfo("html2 -> '\(text)'", category: .document) }
            return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        return text
    }

    // BeamText Version:
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func visit(_ node: SwiftSoup.Node) -> BeamText {
        var text = BeamText()
        if let element = node as? SwiftSoup.Element {
            switch element.tagName() {
            case "a":
                var title: BeamText = visitChildren(element).trimming(.whitespaces)
                guard let href = try? element.attr("href") else { break }
                let url: String = getUrl(href)
                title.addAttributes([.link(url)], to: title.wholeRange)
                text.append(title)

            case "span":
                if debug { Logger.shared.logInfo(tabs + "span...", category: .document) }
                let contents: BeamText = visitChildren(element)
                text.append(contents)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "i": fallthrough

            case "em":
                var contents: BeamText = visitChildren(element)
                contents.addAttributes([.emphasis], to: contents.wholeRange)
                text.append(contents)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "b": fallthrough

            case "strong":
                var contents: BeamText = visitChildren(element)
                contents.addAttributes([.strong], to: contents.wholeRange)
                text.append(contents)

            case "img":
                guard let src = getImageSrc(element),
                      let url: URL = getUrl(src) else { break }
                let mdUrl = url.absoluteString
                var title = BeamText(text: mdUrl)
                title.addAttributes([.link(mdUrl)], to: title.wholeRange)
                text.append(title)

            case "iframe":
                guard let src = getImageSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                var title = BeamText(text: mdUrl)
                title.addAttributes([.link(mdUrl)], to: title.wholeRange)
                text.append(title)

            case "video":
                guard let src = getVideoSrc(element),
                      let url: URL = getUrl(src),
                      let mdUrl = url.absoluteString.markdownizedURL else { break }
                let embedUrl = urlBase.embed ?? url.embed
                if let mdEmbedUrl = embedUrl?.absoluteString.markdownizedURL {
                    var title = BeamText(text: mdEmbedUrl)
                    title.addAttributes([.link(mdEmbedUrl)], to: title.wholeRange)
                    text.append(title)
                } else {
                    var title = BeamText(text: src)
                    title.addAttributes([.link(mdUrl)], to: title.wholeRange)
                    text.append(title)
                }

            default:
                let contents: BeamText = visitChildren(element)
                text.append(contents)
                if isDefaultBlockLevelElement(element) {
                    text.append("\n")
                }
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let string = textNode.text().components(separatedBy: CharacterSet.controlCharacters).joined()
                text.append(string)
            }
            let contents: BeamText = visitChildren(node)
            text.append(contents)
        }

        if depth == 0 {
            if debug { Logger.shared.logInfo("html2 -> '\(text)'", category: .document) }
            return text
        }

        return text
    }

    func visitChildren(_ node: SwiftSoup.Node) -> String {
        guard node.childNodeSize() != 0 else { return "" }
        depth += 1
        let result = node.getChildNodes().reduce("") { previous, node -> String in
            previous + visit(node)
        }
        depth -= 1

        return result
    }

    func visitChildren(_ node: SwiftSoup.Node) -> BeamText {
        guard node.childNodeSize() != 0 else { return BeamText() }
        depth += 1
        var result = BeamText()
        for child in node.getChildNodes() {
            let res: BeamText = visit(child)
            result.append(res)
        }
        depth -= 1

        return result
    }

    /// Check if element is a default block level element.
    /// Based on this MDN list: https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements
    /// - Parameter element: SwiftSoup.Element
    /// - Returns: Boolean, true if block element
    fileprivate func isDefaultBlockLevelElement(_ element: SwiftSoup.Element) -> Bool {
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

    fileprivate func getUrl(_ src: String) -> String {
        if let u = URL(string: src), u.host != nil {
            return u.absoluteString.markdownizedURL!
        }

        if let u = URL(string: src, relativeTo: urlBase), u.host != nil {
            return u.absoluteString.markdownizedURL!
        }

        return src
    }

    fileprivate func getUrl(_ src: String) -> URL? {
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
    fileprivate func getIframeSrc(_ element: Element) -> String? {
        if let src = try? element.attr("src") {
            return src
        }

        return nil
    }

    /// Gets the `src` of an image element
    /// - Parameter element: image element
    /// - Returns: src string or nil
    fileprivate func getImageSrc(_ element: Element) -> String? {
        if let src = try? element.attr("src") {
            return src
        }

        return nil
    }

    /// Gets the `src` of an video element. Supports video elements without `src` attribute that does have children with a `src` tag containing an mp4.
    /// - Parameter element: video element
    /// - Returns: src string or nil
    fileprivate func getVideoSrc(_ element: Element) -> String? {
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

func html2Md(url: URL, html: String) -> String {
    do {
        //Logger.shared.logInfo("html -> \(html)")
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Md(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        Logger.shared.logError("\(type): \(message)", category: .document)
    } catch {
        Logger.shared.logError("html2Md: error", category: .document)
    }

    return ""
}

func html2Text(url: URL, html: String) -> String {
    do {
        //Logger.shared.logInfo("html -> \(html)")
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Text(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        Logger.shared.logError("\(type): \(message)", category: .document)
    } catch {
        Logger.shared.logError("html2Text: error", category: .document)
    }

    return ""
}

func html2Text(url: URL, html: String) -> BeamText {
    do {
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Text(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        Logger.shared.logError("\(type): \(message)", category: .document)
    } catch {
        Logger.shared.logError("html2Text: error", category: .document)
    }

    return BeamText()
}

func html2Text(url: URL, html: String) -> [BeamText] {
    do {
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Text(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        Logger.shared.logError("\(type): \(message)", category: .document)
    } catch {
        Logger.shared.logError("html2Text: error", category: .document)
    }

    return [BeamText()]
}

func html2Md(url: URL, doc: SwiftSoup.Document) -> String {
    let visitor = HtmlVisitor(url)
    let result = visitor.visitMD(doc)
    return result
}

func html2Text(url: URL, doc: SwiftSoup.Document) -> String {
    let visitor = HtmlVisitor(url)
    return visitor.visit(doc)
}

func html2Text(url: URL, doc: SwiftSoup.Document) -> BeamText {
    let visitor = HtmlVisitor(url)
    let text: BeamText = visitor.visit(doc)
    return text.trimming(NSCharacterSet.whitespacesAndNewlines)
}

func html2Text(url: URL, doc: SwiftSoup.Document) -> [BeamText] {
    let visitor = HtmlVisitor(url)
    let fullText: BeamText = visitor.visit(doc)
    return fullText.splitting(NSCharacterSet.newlines).map({ text in
        return text.trimming(.whitespaces)
    })
}

func html2TextForClustering(doc: SwiftSoup.Document) -> String {
    var cleanedText = ""
    var alternateCleanedText = [String]()

    do {
        let paragraphs = try doc.select("p")
        for paragraph in paragraphs.array() {
            for node in paragraph.getChildNodes() {
                if let element = node as? SwiftSoup.Element {
                    switch element.tagName() {
                    case "a":
                        let aText = try element.text()
                        cleanedText.append(aText)
                    default:
                        cleanedText.append("")
                    }
                } else {
                    if let textNode = node as? SwiftSoup.TextNode {
                        cleanedText.append(textNode.text())
                    }
                }
                let myText = try paragraph.text()
                if !alternateCleanedText.contains(myText) {
                    alternateCleanedText += [myText]
                }
            }
        }
    } catch {
        Logger.shared.logError("html2TextForClustering: error", category: .document)
    }
    return alternateCleanedText.max(by: {$1.count > $0.count}) ?? cleanedText
}

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
    // swiftlint:disable:next file_length
}
