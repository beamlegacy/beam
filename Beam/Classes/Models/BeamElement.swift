//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//

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
    @Published public private(set) var id = UUID() { didSet { change() } }
    @Published var text = BeamText() { didSet { change() } }
    @Published var open = true { didSet { change() } }
    @Published public internal(set) var children = [BeamElement]() { didSet { change() } }
    @Published var readOnly = false { didSet { change() } }
    @Published var score: Float = 0 { didSet { change() } }
    @Published var creationDate = Date() { didSet { change() } }
    @Published var updateDate = Date()
    @Published var kind: ElementKind = .bullet { didSet { change() } }
    @Published var childrenFormat: ElementChildrenFormat = .bullet { didSet { change() } }

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

    @Published var parent: BeamElement?

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    func connectUnlinkedNotes(_ thisNoteTitle: String, _ allNotes: [BeamNote]) {
        for note in allNotes where thisNoteTitle != note.title {
            let existingLinks = text.internalLinks.map { range -> String in range.string }
            if text.text.contains(note.title) && !existingLinks.contains(note.title) {
                note.addUnlinkedReference(NoteReference(noteName: thisNoteTitle, elementID: id))
//                Logger.shared.logInfo("New unlink \(thisNoteTitle) --> \(note.title)", category: .document)
            }
        }

        for c in children {
            c.connectUnlinkedNotes(thisNoteTitle, allNotes)
        }
    }

    @Published var changed = 0
    var changePropagationEnabled = true
    func change() {
        guard changePropagationEnabled else { return }
        updateDate = Date()
        changed += 1

        parent?.childChanged()
    }

    func childChanged() {
        change()
        parent?.childChanged()
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

    func detectLinkedNotes(_ documentManager: DocumentManager) {
        guard let note = note else { return }

        for link in text.internalLinks where link.string != note.title {
            let linkTitle = link.string
//            Logger.shared.logInfo("searching link \(linkTitle)", category: .document)
            let refnote = BeamNote.fetchOrCreate(documentManager, title: linkTitle)
            let reference = NoteReference(noteName: note.title, elementID: id)
//            Logger.shared.logInfo("New link \(note.title) <-> \(linkTitle)", category: .document)
            refnote.addLinkedReference(reference)
        }

        for c in children {
            c.detectLinkedNotes(documentManager)
        }
    }

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

}
