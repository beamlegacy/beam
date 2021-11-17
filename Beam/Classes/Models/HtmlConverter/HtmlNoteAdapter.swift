//
//  HtmlNoteAdapter.swift
//  Beam
//
//  Created by Sebastien Metrot on 05/11/2020.
//

import Foundation
import SwiftSoup
import BeamCore
import Promises

// The HtmlNoteAdapter should be instantiated for each time html is parsed. Instantiating
// a global HtmlNoteAdapter could create unexpected behaviour with downloading images
class HtmlNoteAdapter {
    var url: URL
    var visitor: HtmlVisitor

    init(_ url: URL, _ downloadManager: DownloadManager? = nil, _ fileStorage: BeamFileStorage? = nil) {
        self.url = url
        self.visitor = HtmlVisitor(url, downloadManager, fileStorage)
    }

    init?(_ url: String, _ downloadManager: DownloadManager? = nil, _ fileStorage: BeamFileStorage? = nil) {
        guard let url = URL(string: url) else {
            return nil
        }

        self.url = url
        self.visitor = HtmlVisitor(url, downloadManager, fileStorage)
    }

    /// Converts a html string to a plain text string of the content
    /// - Parameter html: String of html content
    /// - Returns: Plain text string
    func convert(html: String, completion: @escaping (String) -> Void) {
        guard let document = parseBodyFragment(html) else {
            completion("")
            return
        }
        convertDocument(document, completion: { wrapperElement in
            completion(wrapperElement.text.text)
        })
    }

    /// Converts a html string to a single BeamElement. Each child of
    /// the BeamElement will get inserted as a bullet
    /// - Parameter html: String of html content
    /// - Returns: BeamElement
    func convert(html: String, completion: @escaping (BeamElement) -> Void) {
        guard let document = parseBodyFragment(html) else {
            completion(BeamElement())
            return
        }
        convertDocument(document, completion: { elements in
            completion(elements)
        })
    }

    /// Converts a html string to an array of BeamElements. Each BeamElement
    /// will get inserted as a bullet.
    /// - Parameter html: String of html content
    /// - Returns: Array of BeamElements
    func convert(html: String, completion: @escaping ([BeamElement]) -> Void) {
        guard let document = parseBodyFragment(html) else {
            completion([])
            return
        }
        convertDocument(document, completion: { elements in
            completion(elements)
        })
    }

    private func convertDocument(_ document: SwiftSoup.Document, completion: @escaping (BeamElement) -> Void) {
        // Visit all html elements and parse them into BeamElements
        // each Html Element will be converted to a BeamElement
        visitor.parse(document, completion: { elements in
            // Each BeamElement will be represented in the journal as a bullet,
            // some content like links in paragraph we want to display them inline.
            // To do so we create a wrapper element to add the children to:
            let wrapperElement = BeamElement()
            wrapperElement.addChildren(elements)
            // Join all BeamElement of bullet kind into whole paragraphs
            wrapperElement.joinKinds()
            // Then split those paragraphs into BeamElements based on line breaks
            // Take care to not lose the reference to the original child with `.image` kind.
            // Losing this reference will make the downloader fail.
            let newChildren = wrapperElement.children.map({ child -> [BeamElement] in
                if child.kind == .bullet {
                    return child.text
                        .splitting(NSCharacterSet.newlines)
                        .compactMap({ text -> BeamElement? in
                            let resultText = text.trimming(.whitespaces)
                            return resultText.count > 0 ? BeamElement(resultText) : nil
                        })
                } else {
                    return [child]
                }
            })
            // flatten arrays of arrays
            .reduce([], +)
            // Assign the newChildren to the wrapperElement
            wrapperElement.clearChildren()
            wrapperElement.addChildren(newChildren)

            completion(wrapperElement)
        })
    }

    private func convertDocument(_ document: SwiftSoup.Document, completion: @escaping ([BeamElement]) -> Void) {
        let parentCompletion = completion
        convertDocument(document, completion: { wrapperElement in
            parentCompletion(wrapperElement.children)
        })
    }

    /// Uses SwiftSoup to parse an html string into a SwiftSoup Document
    /// - Parameter html: String of html content
    /// - Returns: SwiftSoup Document
    private func parseBodyFragment(_ html: String) -> SwiftSoup.Document? {
        do {
            return try SwiftSoup.parseBodyFragment(html)
        } catch Exception.Error(let type, let message) {
            Logger.shared.logError("\(type): \(message)", category: .document)
            return nil
        } catch {
            Logger.shared.logError("SwiftSoup.parseBodyFragment: error", category: .document)
            return nil
        }
    }
}

extension HtmlNoteAdapter {
    /// Convert a html string to a simplefied text string with only the paragraph (`<p>`)
    /// text and the anchor tags (`<a>`) inside paragraphs as content.
    /// - Parameter html: String of html content
    /// - Returns: Array of strings
    func convertForClustering(html: String) -> [String] {
        guard let document = parseBodyFragment(html) else {
            return [""]
        }

        var alternateCleanedText = [String]()

        do {
            let paragraphs = try document.select("p")
            for paragraph in paragraphs.array() {
                let myText = try paragraph.text()
                if !alternateCleanedText.contains(myText) {
                    alternateCleanedText += [myText]
                }
            }
        } catch {
            Logger.shared.logError("convertForClustering: error", category: .document)
        }
        return alternateCleanedText
    }
}
