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

    init(_ urlBase: URL) {
        self.urlBase = urlBase
    }

    func visit(_ node: SwiftSoup.Node) -> String {
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
//                    print(tabs + "a href = '\(href)'")
                    text += "["
                    let title = visitChildren(element).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    text += title
                    text += "](\(url))"
                case "span":
//                    print(tabs + "span...")
                    text += visitChildren(element)

                default:
                    text += visitChildren(node)
                }
            } catch Exception.Error(let type, let message) {
                print("\(type): \(message)")
            } catch {
                print("HtmlVisitor: error")
            }
        } else {
            if let textNode = node as? SwiftSoup.TextNode {
                let t = textNode.text()
//                print(tabs + "textNode = '\(t)'")

                text += t
            } else {
//                print(tabs + "??? node ??? = '\(node)'")
            }

            text += visitChildren(node)
        }

        if depth == 0 {
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
        let doc = try SwiftSoup.parseBodyFragment(html)

        let visitor = HtmlVisitor(url)
        return visitor.visit(doc)

    } catch Exception.Error(let type, let message) {
        print("\(type): \(message)")
    } catch {
        print("html2Md: error")
    }

    return ""
}
