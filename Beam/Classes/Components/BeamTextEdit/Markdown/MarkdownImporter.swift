import BeamCore
import Foundation
import Markdown

// MARK: - Importer API

/// A Markdown importer, with a single endpoint allowing to import a Markdown document and save it.
struct MarkdownImporter: BeamDocumentSource {
    static var sourceId: String { "MarkdownImporter" }

    var sourceId: String {
        Self.sourceId
    }

    private static let defaultingName: String = "Markdown Import"

    /// Imports the contents located at the specified URL and saves if wanted.
    /// - Parameters:
    ///   - contents: the Markdown document `URL`.
    ///   - saving: a boolean indicating if you want to save it, defaults to `true`.
    /// - Returns: the `BeamNote` for later processing.
    @discardableResult
    func `import`(documentURL: URL, saving: Bool = true) throws -> BeamNote {
        // Creating the markdown document
        let contents = try String(contentsOf: documentURL)
        let note = try process(markdown: contents, title: documentURL.deletingPathExtension().lastPathComponent, baseURL: documentURL)
        if saving {
            // For every image elements, let's add it to the BeamFileDBManager
            for imageElement in note.imageElements() {
                guard case .image(let uid, _, _) = imageElement.kind else { continue }
                try BeamFileDBManager.shared?.addReference(fromNote: note.id, element: imageElement.id, to: uid)
            }
            // Let's finally save the document
            _ = note.save(self)
        }
        return note
    }

    private func process(markdown: String, title: String, baseURL: URL) throws -> BeamNote {
        let preformatted = preformat(contents: markdown)
        let document = Markdown.Document(parsing: preformatted)
        // Creating the note
        let title = availableNoteName(with: title)
        let note: BeamNote
        do {
            note = try BeamNote.fetchOrCreate(self, title: title)
        } catch BeamNoteError.invalidTitle {
            let defaultTitle = availableNoteName(with: Self.defaultingName)
            note = try BeamNote.fetchOrCreate(self, title: defaultTitle)
        }
        // Let's visit the document and retrieve the root element
        var visitor = BeamNoteVisitor(baseURL: baseURL)
        let element = visitor.visitDocument(document)
        // Prettifying the children of the root element
        element.prettify()
        // Stealing those for the note
        note.children = element.children
        return note
    }

    private func availableNoteName(with startingName: String) -> String {
        var finalName: String = startingName
        var tries: UInt = 1
        while BeamNote.fetch(title: finalName) != nil {
            tries += 1
            finalName = "\(startingName) (\(tries))"
        }
        return finalName
    }

    private func preformat(contents: String) -> String {
        // since with swift-markdown, it seems that the line breaks we add to exported notes (representing empty nodes)
        // are parsed as HTMLBlocks markup elements and include their surrounding content if it doesn't contain spaces
        // (but we didn't want to include them in the export since it adds too much extra spaces)
        return contents.replacingOccurrences(of: "<br>", with: "\n<br>\n")
    }
}

// MARK: - Testing

extension MarkdownImporter {
    /// **Only use this for testing.**
    func _import(markdown: String) throws -> BeamNote {
        return try process(markdown: markdown, title: "Testing", baseURL: URL(fileURLWithPath: "/"))
    }
}

// MARK: - Visitor

// A private visitor instance creating a root BeamElement.
private struct BeamNoteVisitor: MarkupVisitor {

    let baseURL: URL

    let fileManager = BeamFileDBManager.shared

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func defaultVisit(_ markup: Markdown.Markup) -> BeamElement {
        #if DEBUG
        return BeamElement(markup.debugDescription())
        #else
        return BeamElement()
        #endif
    }

    mutating func visitDocument(_ document: Markdown.Document) -> BeamElement {
        let root = BeamElement()
        for markup in document.children {
            let visited = visit(markup)
            if markup is Markdown.Paragraph, visited.children.count > 1 {
                root.addChildren(visited.children)
            } else {
                root.addChild(visited)
            }
        }
        return root
    }

    mutating func visitParagraph(_ paragraph: Markdown.Paragraph) -> BeamElement {
        let root = BeamElement()
        for markup in paragraph.inlineChildren {
            let visited = visit(markup)
            if markup is Text, visited.text.isEmpty {
                // i've seen some cases with empty Text markups, resulting in empty BeamElements that we don't want
                // whereas we want empty BeamElements for LineBreaks
                continue
            }
            root.addChild(visited)
        }
        let childrenCount = root.children.count
        if childrenCount == 1 {
            return root.children[0]
        } else if childrenCount > 1 {
            let newChildren: [BeamElement] = root.children.reduce(into: []) { partialResult, newElement in
                if partialResult.isEmpty || newElement.text.isEmpty || !newElement.imageElements().isEmpty {
                    partialResult.append(newElement)
                } else {
                    partialResult.last?.text.append(newElement.text)
                }
            }
            root.children = newChildren
            return root.children.count == 1 ? root.children[0] : root
        } else {
            // This case shouldn't happen ? Otherwise it meant that the paragraph was empty...
            return root
        }
    }

    mutating func visitUnorderedList(_ unorderedList: Markdown.UnorderedList) -> BeamElement {
        let root = BeamElement()
        for markup in unorderedList.listItems {
            let visited = visit(markup)
            visited.bubbleUp(into: root)
        }
        return root
    }

    mutating func visitListItem(_ listItem: Markdown.ListItem) -> BeamElement {
        let root = BeamElement()
        for markup in listItem.blockChildren {
            let visited = visit(markup)
            root.addChild(visited)
        }
        return root.children.count == 1 ? root.children[0] : root
    }

    mutating func visitHeading(_ heading: Markdown.Heading) -> BeamElement {
        let element = BeamElement(heading.plainText)
        element.kind = .heading(heading.level)
        return element
    }

    mutating func visitText(_ text: Markdown.Text) -> BeamElement {
        return BeamElement(text.plainText)
    }

    mutating func visitStrong(_ strong: Markdown.Strong) -> BeamElement {
        return BeamElement(BeamText(strong.plainText, attributes: [.strong]))
    }

    mutating func visitEmphasis(_ emphasis: Markdown.Emphasis) -> BeamElement {
        return BeamElement(BeamText(emphasis.plainText, attributes: [.emphasis]))
    }

    mutating func visitLink(_ link: Markdown.Link) -> BeamElement {
        return BeamElement(BeamText(link.plainText, attributes: [.link(link.destination ?? "")]))
    }

    mutating func visitImage(_ image: Markdown.Image) -> BeamElement {
        let imageTitle = image.title ?? ""
        let imageSource = image.source?.removingPercentEncoding ?? image.source ?? ""

        let title = imageTitle.isEmpty ? image.plainText : imageTitle
        let url = URL(fileURLWithPath: imageSource, relativeTo: baseURL)

        let element = BeamElement(title)

        if let data = try? Data(contentsOf: url), let image = NSImage(contentsOf: url) {
            do {
                if let uid = try fileManager?.insert(name: url.lastPathComponent, data: data) {
                    let displayInfos = MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width))
                    element.kind = .image(uid, displayInfos: displayInfos)
                }
            } catch {
                Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
            }
        }

        return element
    }

    mutating func visitHTMLBlock(_ html: Markdown.HTMLBlock) -> BeamElement {
        if html.rawHTML == "<br>" || html.rawHTML == "<br>\n" {
            return BeamElement()
        } else {
            return BeamElement(html.rawHTML)
        }
    }

    func visitLineBreak(_ lineBreak: Markdown.LineBreak) -> BeamElement {
        return BeamElement()
    }
}

// MARK: - Helpers

private extension BeamElement {
    func prettify() {
        for element in flatElements where element.text.isEmpty && element.children.count >= 1 {
            if let sibblingReceiver = element.previousNonEmptySibbling {
                sibblingReceiver.addChildren(element.children)
                element.parent?.removeChild(element)
            }
        }
    }

    func bubbleUp(into receiver: BeamElement) {
        if let bubbledUp = bubbledUpElements {
            if bubbledUp.count == 1 {
                receiver.addChild(bubbledUp[0])
            } else {
                receiver.addChildren(bubbledUp)
            }
        } else {
            receiver.addChild(self)
        }
    }

    var bubbledUpElements: [BeamElement]? {
        guard text.isEmpty, children.count >= 1 else { return nil }
        return children.count == 1 ? [children[0]] : children
    }

    var previousNonEmptySibbling: BeamElement? {
        var previous = previousSibbling()
        while previous?.text.isEmpty == true {
            previous = previousSibbling()
        }
        return previous
    }
}
