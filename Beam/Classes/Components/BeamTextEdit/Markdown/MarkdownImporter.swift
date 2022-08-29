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

    /// Errors thrown when interacting with the ``MarkdownImporter``.
    enum Error: LocalizedError {
        case alreadyExists

        var errorDescription: String? {
            switch self {
            case .alreadyExists:
                return "A note with this title already exists."
            }
        }
    }

    /// Imports the contents located at the specified URL and saves if wanted.
    /// - Parameters:
    ///   - contents: the Markdown document `URL`.
    ///   - saving: a boolean indicating if you want to save it, defaults to `true`.
    /// - Returns: the `BeamNote` for later processing.
    @discardableResult
    func `import`(contents: URL, saving: Bool = true) throws -> BeamNote {
        // Creating the markdown document
        let document = try Markdown.Document(parsing: contents)
        // Creating the note
        let title = contents.deletingPathExtension().lastPathComponent
        guard BeamNote.fetch(title: title) == nil else {
            throw Error.alreadyExists
        }
        let note = try BeamNote.fetchOrCreate(self, title: title)
        // Let's visit the document and retrieve the root element
        var visitor = BeamNoteVisitor(baseURL: contents)
        let element = visitor.visitDocument(document)
        // Prettifying the children of the root element
        element.prettify()
        // Stealing those for the note
        note.children = element.children
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
            // if we have visited a list, let's add its children to the root directly
            if visited.text.isEmpty, visited.children.count > 1 {
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
            if visited.imageElements().isEmpty {
                root.text.append(visited.text)
            } else {
                root.addChild(visited)
            }
        }
        return root.children.count == 1 ? root.children[0] : root
    }

    mutating func visitUnorderedList(_ unorderedList: Markdown.UnorderedList) -> BeamElement {
        let root = BeamElement()
        for markup in unorderedList.listItems {
            let visited = visit(markup)
            visited.bubbleUp(into: root)
        }
        return root.children.count == 1 ? root.children[0] : root
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
        let imageSource = image.source ?? ""

        let title = imageTitle.isEmpty ? image.plainText : imageTitle
        let url = URL(fileURLWithPath: imageSource, relativeTo: baseURL)

        let element = BeamElement(title)

        if let data = try? Data(contentsOf: url), let image = NSImage(contentsOf: url) {
            do {
                let uid = try fileManager!.insert(name: url.lastPathComponent, data: data)
                let displayInfos = MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width))
                element.kind = .image(uid, displayInfos: displayInfos)
            } catch {
                Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
            }
        }

        return element
    }

}

// MARK: - Helpers

private extension BeamElement {
    func prettify() {
        for element in flatElements where element.text.isEmpty {
            let childrenCount = element.children.count
            if childrenCount > 1, let previousSibbling = element.previousSibbling() {
                previousSibbling.addChildren(element.children)
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
}
