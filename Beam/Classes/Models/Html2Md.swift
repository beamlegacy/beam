//
//  Html2Md.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation
import SwiftSoup

class HtmlVisitor {
    var depth = 0
    var tabs: String { String.tabs(depth) }
    var urlBase: URL
    var keepFormatting: Bool = false

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
                    if debug { print(tabs + "a href = '\(href)'") }
                    text += "["
                    let title = visitChildrenMD(element).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    text += title
                    text += "](\(url))"
                case "span":
                    if debug { print(tabs + "span...") }
                    text += visitChildrenMD(element)

                // swiftlint:disable:next fallthrough no_fallthrough_only
                case "i": fallthrough
                case "em":
                    if debug { print(tabs + "em...") }
                    let contents = visitChildrenMD(element)
                    if keepFormatting {
                        text += "_**" + contents + "**_"
                    } else {
                        text += contents
                    }

                // swiftlint:disable:next fallthrough no_fallthrough_only
                case "b": fallthrough
                case "strong":
                    if debug { print(tabs + "strong...") }
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
                print("\(type): \(message)")
            } catch {
                print("HtmlVisitor: error")
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let t = textNode.text()
                if debug { print(tabs + "textNode = '\(t)'") }

                text += t
            } else {
                if debug { print(tabs + "??? node ??? = '\(node)'") }
            }

            text += visitChildrenMD(node)
        }

        if depth == 0 {
            if debug { print("html2Md -> '\(text)'") }
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
                if debug { print(tabs + "span...") }
                text += visitChildren(element)

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "i": fallthrough
            case "em":
                let contents = visitChildren(element)
                text += contents

            // swiftlint:disable:next fallthrough no_fallthrough_only
            case "b": fallthrough
            case "strong":
                let contents = visitChildren(element)
                text += contents

            default:
                text += visitChildren(node)
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let t = textNode.text()
                text += t
            }
            text += visitChildren(node)
        }

        if depth == 0 {
            if debug { print("html2 -> '\(text)'") }
            return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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

}

func html2Md(url: URL, html: String) -> String {
    do {
        //print("html -> \(html)")
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Md(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        print("\(type): \(message)")
    } catch {
        print("html2Md: error")
    }

    return ""
}

func html2Text(url: URL, html: String) -> String {
    do {
        //print("html -> \(html)")
        let doc = try SwiftSoup.parseBodyFragment(html)

        return html2Text(url: url, doc: doc)
    } catch Exception.Error(let type, let message) {
        print("\(type): \(message)")
    } catch {
        print("html2Text: error")
    }

    return ""
}

func html2Md(url: URL, doc: SwiftSoup.Document) -> String {
    let visitor = HtmlVisitor(url)
    let result = visitor.visitMD(doc)
    return result
}

func html2Text(url: URL, doc: SwiftSoup.Document) -> String {
    let visitor = HtmlVisitor(url)
    let result = visitor.visit(doc)
    return result
}
