//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine

enum ElementKindError: Error {
    case typeNameUnknown(String)
}

enum ElementKind: Codable, Equatable {
    case bullet
    case heading(Int)
    case quote(Int, String, String)
    case code

    enum CodingKeys: String, CodingKey {
        case type
        case level
        case source
        case title
    }

    var rawValue: String {
       switch self {
       case .bullet:
           return "bullet"
       case .heading(let level):
           return "heading \(level)"
       case .quote:
           return "quote"
       case .code:
           return "code"
       }
   }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let typeName = try container.decode(String.self, forKey: .type)
        switch typeName {
        case "bullet":
            self = .bullet
        case "heading":
            self = .heading(try container.decode(Int.self, forKey: .level))
        case "quote":
            self = .quote(try container.decode(Int.self, forKey: .level),
                            try container.decode(String.self, forKey: .source),
                            try container.decode(String.self, forKey: .title))
        case "code":
            self = .code
        default:
            throw ElementKindError.typeNameUnknown(typeName)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .bullet:
            try container.encode("bullet", forKey: .type)
        case let .heading(level):
            try container.encode("heading", forKey: .type)
            try container.encode(level, forKey: .level)
        case let .quote(level, source, title):
            try container.encode("quote", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(source, forKey: .source)
            try container.encode(title, forKey: .title)
        case .code:
            try container.encode("code", forKey: .type)
        }
    }
}

enum ElementChildrenFormat: String, Codable {
    case bullet
    case numbered
}

// Editable Text Data:
public class BeamElement: Codable, Identifiable, Hashable, ObservableObject, CustomDebugStringConvertible {
    @Published public private(set) var id = UUID() { didSet { change(.meta) } }
    @Published var text = BeamText() { didSet { change(.text) } }
    @Published var open = true { didSet { change(.meta) } }
    @Published public internal(set) var children = [BeamElement]() { didSet { change(.tree) } }
    @Published var readOnly = false { didSet { change(.meta) } }
    @Published var score: Float = 0 { didSet { change(.meta) } }
    @Published var creationDate = Date() { didSet { change(.meta) } }
    @Published var updateDate = Date()
    @Published var kind: ElementKind = .bullet { didSet { change(.meta) } }
    @Published var childrenFormat: ElementChildrenFormat = .bullet { didSet { change(.meta) } }
    @Published var query: String?

    var note: BeamNote? {
        return parent?.note
    }

    static let recursiveCoding = CodingUserInfoKey(rawValue: "recursiveCoding")!

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case open
        case children
        case readOnly
        case score
        case creationDate
        case kind
        case childrenFormat
        case query
    }

    init() {
    }

    init(_ text: String) {
        self.text = BeamText(text: text, attributes: [])
    }

    init(_ text: BeamText) {
        self.text = text
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let recursive = decoder.userInfo[Self.recursiveCoding] as? Bool ?? true

        id = try container.decode(UUID.self, forKey: .id)
        do {
            text = try container.decode(BeamText.self, forKey: .text)
        } catch {
            let _text = try container.decode(String.self, forKey: .text)
            text = BeamText(text: _text, attributes: [])
        }
        open = try container.decode(Bool.self, forKey: .open)
        readOnly = try container.decode(Bool.self, forKey: .readOnly)

        if container.contains(.score) {
            score = try container.decode(Float.self, forKey: .score)
        }

        if container.contains(.creationDate) {
            creationDate = try container.decode(Date.self, forKey: .creationDate)
        }

        if recursive, container.contains(.children) {
            children = try container.decode([BeamElement].self, forKey: .children)
            for child in children {
                child.parent = self
            }
        }

        if container.contains(.kind) {
            kind = try container.decode(ElementKind.self, forKey: .kind)
        }

        if container.contains(.childrenFormat) {
            childrenFormat = try container.decode(ElementChildrenFormat.self, forKey: .childrenFormat)
        }

        if container.contains(. query) {
            query = try container.decode(String.self, forKey: .query)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let recursive = encoder.userInfo[Self.recursiveCoding] as? Bool ?? true

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(open, forKey: .open)
        try container.encode(readOnly, forKey: .readOnly)
        try container.encode(score, forKey: .score)
        try container.encode(creationDate, forKey: .creationDate)
        if recursive, !children.isEmpty {
            try container.encode(children, forKey: .children)
        }

        switch kind {
        case .bullet:
            break
        default:
            try container.encode(kind, forKey: .kind)
        }

        if childrenFormat != .bullet {
            try container.encode(childrenFormat, forKey: .childrenFormat)
        }

        if let q = query {
            try container.encode(q, forKey: .query)
        }
    }

    func clearChildren() {
        for c in children {
            c.parent = nil
        }
        children = []
    }

    func removeChild(_ child: BeamElement) {
        guard let index = children.firstIndex(where: { (e) -> Bool in
            e === child
        }) else { return }
        children.remove(at: index)
        child.parent = nil
    }

    func indexOfChild(_ child: BeamElement) -> Int? {
        return children.firstIndex(where: { (e) -> Bool in
            e === child
        })
    }

    func addChild(_ child: BeamElement) {
        insert(child, after: children.last) // append
    }

    func insert(_ child: BeamElement, after: BeamElement?) {
        if let oldParent = child.parent {
            oldParent.removeChild(child)
        }

        child.parent = self
        guard let after = after, let index = indexOfChild(after) else {
            children.insert(child, at: 0)
            return
        }

        children.insert(child, at: index + 1)
    }

    func insert(_ child: BeamElement, at pos: Int) {
        if let oldParent = child.parent {
            oldParent.removeChild(child)
        }

        child.parent = self
        children.insert(child, at: pos)
    }

    weak var parent: BeamElement?

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    func getDeepUnlinkedReferences(_ thisNoteTitle: String, _ allNames: [String]) -> [String: [NoteReference]] {
        var references = getUnlinkedReferences(thisNoteTitle, allNames)
        for c in children {
            for res in c.getDeepUnlinkedReferences(thisNoteTitle, allNames) {
                references[res.key] = (references[res.key] ?? []) + res.value
            }
        }

        return references
    }

    func getUnlinkedReferences(_ thisNoteTitle: String, _ allNames: [String]) -> [String: [NoteReference]] {
        var references = [String: [NoteReference]]()
        let existingLinks = text.internalLinks.map { range -> String in range.string }
        let string = text.text

        for noteName in allNames where thisNoteTitle != noteName {
            if !existingLinks.contains(noteName), string.contains(noteName) {
                let ref = NoteReference(noteName: thisNoteTitle, elementID: id)
                references[noteName] = (references[noteName] ?? []) + [ref]
//                Logger.shared.logInfo("New unlink \(thisNoteTitle) --> \(note.title)", category: .document)
            }
        }

        return references
    }

    func connectUnlinkedElement(_ thisNoteTitle: String, _ allNames: [String]) {
        let results = getUnlinkedReferences(thisNoteTitle, allNames)
        for (name, refs) in results {
            let note = BeamNote.fetchOrCreate(AppDelegate.main.data.documentManager, title: name)
            for ref in refs {
                note.addReference(ref)
            }
        }
    }

    @Published var changed: (BeamElement, ChangeType)?
    var changePropagationEnabled = true
    enum ChangeType {
        case text, meta, tree
    }
    func change(_ type: ChangeType) {
        guard changePropagationEnabled else { return }
        updateDate = Date()
        changed = (self, type)

        parent?.childChanged(self, type)
    }

    func childChanged(_ child: BeamElement, _ type: ChangeType) {
        guard changePropagationEnabled else { return }
        updateDate = Date()
        changed = (child, type)

        parent?.childChanged(self, type)
    }

    func findElement(_ id: UUID) -> BeamElement? {
        guard id != self.id else { return self }

        for c in children {
            if let result = c.findElement(id) {
                return result
            }
        }

        return nil
    }

    func detectLinkedNotes(_ documentManager: DocumentManager, async: Bool) {
        guard let note = note else { return }
        let sourceNote = note.title

        for link in text.internalLinks where link.string != note.title {
            let linkTitle = link.string
            //            Logger.shared.logInfo("searching link \(linkTitle)", category: .document)
            let reference = NoteReference(noteName: sourceNote, elementID: id)
            //            Logger.shared.logInfo("New link \(note.title) <-> \(linkTitle)", category: .document)

            if async {
                DispatchQueue.main.async {
                    let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
                    refnote.addReference(reference)
                }
            } else {
                let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
                refnote.addReference(reference)
            }
        }

        for c in children {
            c.detectLinkedNotes(documentManager, async: async)
        }
    }

    // TODO: use this for smart merging
    func recursiveUpdate(other: BeamElement) {
        assert(other.id == id)

        changePropagationEnabled = false
        defer {
            changePropagationEnabled = true
        }

        text = other.text
        open = other.open
        readOnly = other.readOnly
        score = other.score
        creationDate = other.creationDate
        updateDate = other.updateDate
        kind = other.kind
        childrenFormat = other.childrenFormat

        var oldChildren = [UUID: BeamElement]()
        for c in children {
            oldChildren[c.id] = c
        }

        var newChildren = [BeamElement]()
        for c in other.children {
            if let child = oldChildren[c.id] {
                child.recursiveUpdate(other: c)
                newChildren.append(child)
            } else {
                newChildren.append(c)
            }
        }

        children = newChildren
    }

    public var debugDescription: String {
        return "BeamElement(\(id) [\(children.count) children] \(kind) - \(childrenFormat) \(!open ? "[closed]" : ""): \(text.text)"
    }

    var isHeader: Bool {
        switch kind {
        case .heading:
            return true
        default:
            return false
        }
    }

    var flatElements: [BeamElement] {
        var elems = children
        for c in children {
            elems += c.flatElements
        }

        return elems
    }

    func readLock() {
        note?.readLock()
    }

    func readUnlock() {
        note?.readUnlock()
    }

    func writeLock() {
        note?.writeLock()
    }

    func writeUnlock() {
        note?.writeUnlock()
    }

    var depth: Int {
        guard let depth = parent?.depth else { return 0 }
        return depth + 1
    }

    func hasLinkToNote(named noteName: String) -> Bool {
        text.hasLinkToNote(named: noteName)
    }

    func hasReferenceToNote(named noteName: String) -> Bool {
        text.hasReferenceToNote(named: noteName)
    }

    public var outLinks: [String] {
        text.links + children.flatMap { $0.outLinks }
    }

    func elementContainingLink(to link: String) -> BeamElement? {
        if text.links.contains(link) {
            return self
        }

        for c in children {
            if let element = c.elementContainingLink(to: link) {
                return element
            }
        }

        return nil
    }
}
