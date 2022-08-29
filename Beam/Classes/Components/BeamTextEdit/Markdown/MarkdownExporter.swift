import BeamCore
import Foundation

// MARK: Document model

/// An export of a ``BeamNote`` in Markdown.
struct BeamNoteMarkdownExport {
    static let fileExtension: String = "md"

    /// The title of the document and name of the exported file by default.
    let title: String
    /// The Markdown contents of the document.
    private(set) var contents: String

    /// Attachments referenced in the Markdown contents.
    private var attachments: [BeamFileRecord]

    /// Creates a Markdown export of a note.
    /// - Parameter title: title of the export.
    fileprivate init(title: String) {
        self.title = title
        self.contents = ""
        self.attachments = []
    }

    /// Writes the Markdown contents and associated attachments to the specified URL.
    ///
    /// If the URL points to a directory, then filename will be the title of the export.
    /// Otherwise, it respects the provided URL.
    /// - Parameter url: the destination URL.
    func write(to url: URL) throws {
        let markdownURL: URL
        let attachmentsURL: URL
        let sanitizedTitle: String = title.sanitized
        if url.hasDirectoryPath {
            markdownURL = url.appendingPathComponent(sanitizedTitle).appendingPathExtension(Self.fileExtension)
            attachmentsURL = url
        } else {
            markdownURL = url
            attachmentsURL = url.deletingLastPathComponent()
        }
        try contents.write(to: markdownURL, atomically: true, encoding: .utf8)
        try writeAttachments(to: attachmentsURL, sanitizedPrefix: sanitizedTitle) // watch out for security scopes if you're writing somewhere special
    }

    /// Writes attachments to the directory where the Markdown contents export will be located.
    private func writeAttachments(to baseURL: URL, sanitizedPrefix: String) throws {
        for attachment in attachments {
            let dstURL = baseURL
                .appendingPathComponent(attachment.sanitizedFilename(withSanitizedPrefix: sanitizedPrefix))
                .appendingPathExtension(attachment.type)
            try dstURL.performWithSecurityScopedResource { url in
                try attachment.data.write(to: url)
            }
        }
    }
}

private extension BeamNoteMarkdownExport {
    /// Appends Markdown content to the receiver.
    /// - Parameters:
    ///   - markdown: the Markdown string.
    ///   - shouldPrettify: whether it should gives some space around headings, `true` by default.
    mutating func append(_ markdown: String) {
        if !contents.isEmpty {
            appendNewlines(count: 2)
        }
        contents.append(markdown)
    }

    /// Appends newlines to the document.
    /// - Parameter count: the amount of newlines to add.
    mutating func appendNewlines(count: UInt) {
        for _ in 0..<count {
            appendNewline()
        }
    }

    /// Appends a newline to the document.
    mutating func appendNewline() {
        contents.append(.newline)
    }

    /// Appends attachments to the receiver.
    mutating func appendAttachments(_ newAttachments: [BeamFileRecord]) {
        attachments.append(contentsOf: newAttachments)
    }
}

// MARK: Exporter

/// A Markdown exporter, with a single endpoint allowing to export a note to a Markdown document.
enum MarkdownExporter {

    /// Exports a ``BeamNote`` to a ``BeamNoteMarkdownExport``.
    /// - Parameter note: a  ``BeamNote`` instance.
    /// - Returns: A Markdown export if it succeeds, throws with appropriate otherwise.
    static func export(of note: BeamNote) -> BeamNoteMarkdownExport {
        let noteToExport: BeamNote
        if note.isEntireNoteEmpty(), let fetchedNote = BeamNote.fetch(id: note.id, keepInMemory: false) {
            noteToExport = fetchedNote
        } else {
            noteToExport = note
        }
        var document = BeamNoteMarkdownExport(title: noteToExport.title)
        for (content, attachments) in noteToExport.children.compactMap({ Self.content(for: $0, filenamePrefix: noteToExport.title) }) {
            document.append(content)
            document.appendAttachments(attachments)
        }
        return document
    }

}

/// We need to keep track of attachments we encounter across each run of the ``content(for:level:)`` function for
/// every child element of the main ``BeamNote`` document.
typealias MarkdownContent = (content: String, attachments: [BeamFileRecord])

private extension MarkdownExporter {

    /// Provides content for a ``BeamElement``.
    /// - Parameters:
    ///   - child: the ``BeamElement`` instance.
    ///   - filenamePrefix: a prefix to use for all the filenames attachment of the export.
    ///   - level: the level at which we render the element.
    /// - Returns: Markdown content if any, `nil` otherwise.
    static func content(for child: BeamElement, filenamePrefix: String, level: Int = .zero) -> MarkdownContent? {
        switch child.kind {
        case .bullet where child.children.isEmpty:
            guard !child.text.isEmpty else { return nil }
            return (render(child.text.markdown, deepLevel: level), [])

        case .bullet:
            guard !child.text.isEmpty else { return nil }
            let subContent = child.children.reduce(into: (String.empty, [])) { partialResult, element in
                Self.content(for: element, filenamePrefix: filenamePrefix, level: level+1).map {
                    partialResult = (partialResult.0 + $0.0, partialResult.1 + $0.1)
                }
            }
            let headerContent = render(child.text.markdown, deepLevel: level)
            let finalHeaderContent = level == .zero ? (headerContent + .newline) : headerContent
            return (finalHeaderContent + subContent.0, subContent.1)

        case .heading(let headingLevel) where child.children.isEmpty:
            let heading = child.text.text
            guard !heading.isEmpty else { return nil }
            return (render(headingify(heading, headingLevel: headingLevel), deepLevel: level), [])

        case .heading(let headingLevel):
            let heading = child.text.text
            guard !heading.isEmpty else { return nil }
            let subContent = child.children.reduce(into: (String.empty, [])) { partialResult, element in
                Self.content(for: element, filenamePrefix: filenamePrefix, level: level+1).map {
                    partialResult = (partialResult.0 + $0.0, partialResult.1 + $0.1)
                }
            }
            let headerContent = render(headingify(heading, headingLevel: headingLevel), deepLevel: level)
            let finalHeaderContent = level == .zero ? (headerContent + .newline) : headerContent
            return (finalHeaderContent + subContent.0, subContent.1)

        case .check(let checked):
            return (render(checkify(child.text.markdown, checked: checked), deepLevel: level), [])

        case .code:
            return (render(codify(child.text.text), deepLevel: level), [])

        case .divider:
            return (.markdownDivider, [])

        case .embed(let url, _, _):
            return (render(linkify(title: child.text.text, url: url.absoluteString), deepLevel: level), [])

        case .image(let uuid, _, _):
            guard let file = try? BeamFileDBManager.shared?.fetch(uid: uuid) else {
                return nil
            }
            let sanitizedFilename = file.sanitizedFilename(withSanitizedPrefix: filenamePrefix.sanitized)
            return (render("![\(file.name)](\(sanitizedFilename))", deepLevel: level), [file])

        default:
            return nil
        }
    }
}

private extension MarkdownExporter {
    /// Render some content with the proper indentation.
    /// - Parameters:
    ///   - content: the Markdown content to render.
    ///   - deepLevel: the indentation level, usually the deep level of the node.
    /// - Returns: the Markdown content, indented if necessary.
    static func render(_ content: String, deepLevel: Int) -> String {
        if deepLevel > .zero {
            let indenting = String(repeating: "  ", count: deepLevel)
            return .newline + indenting + "* " + content
        } else {
            return content
        }
    }

    /// Displays some text as a heading.
    /// - Parameters:
    ///   - content: the heading text.
    ///   - headingLevel: the heading level.
    /// - Returns: the Markdown heading with the specified level.
    static func headingify(_ content: String, headingLevel: Int) -> String {
        String(repeating: "#", count: headingLevel).appending(" ").appending(content)
    }

    /// Displays an item with a checkbox before.
    /// - Parameters:
    ///   - content: the content of the item.
    ///   - checked: the checkbox state.
    /// - Returns: the Markdown content of the check item.
    static func checkify(_ content: String, checked: Bool) -> String {
        "- \(checked ? "[x]" : "[ ]") \(content)"
    }

    /// Displays some code content.
    /// - Parameter content: the code source.
    /// - Returns: the Markdown content of the source code.
    static func codify(_ content: String) -> String {
        """
        ```
        \(content)
        ```
        """
    }

    /// Displays a link.
    /// - Parameters:
    ///   - title: the title of the link.
    ///   - url: the URL as a string.
    /// - Returns: the Markdown content of the link.
    static func linkify(title: String, url: String) -> String {
        "[\(title)](\(url))"
    }
}

private extension BeamFileRecord {
    func sanitizedFilename(withSanitizedPrefix sanitizedPrefix: String) -> String {
        return sanitizedPrefix.appending("_").appending(name.sanitized)
    }
}

private extension BeamText {
    /// Renders as Markdown for all ranges of the receiver.
    var markdown: String {
        return ranges.map(\.markdown).joined()
    }
}

private extension BeamText.Range {
    /// Renders the receiver content as Markdown.
    var markdown: String {
        if attributes.isEmpty {
            return string
        } else {
            switch attributes[0] {
            case .strong:
                return string.surround(with: .markdownStrong)
            case .emphasis:
                return string.surround(with: .markdownEmphasis)
            case .strikethrough:
                return string.surround(with: .markdownStrikethrough)
            case .link(let url):
                return "[\(string)](\(url))"
            default:
                return string
            }
        }
    }
}

private extension String {
    static var markdownStrong: String {
        "**"
    }

    static var markdownEmphasis: String {
        "*"
    }

    static var markdownStrikethrough: String {
        "~~"
    }

    static var markdownDivider: String {
        "---"
    }

    static var empty: String {
        ""
    }

    static var newline: String {
        "\n"
    }

    func surround(with delimitor: String) -> String {
        "\(delimitor)\(self)\(delimitor)"
    }

    var sanitized: String {
        return replacingOccurrences(of: "/", with: ":")
    }
}

private extension URL {
    func performWithSecurityScopedResource(work: (URL) throws -> Void) rethrows {
        let result = startAccessingSecurityScopedResource()
        try work(self)
        if !result {
            stopAccessingSecurityScopedResource()
        }
    }
}
