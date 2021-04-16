//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//
// swiftlint:disable file_length

import Foundation
import Combine

public enum ElementKindError: Error {
    case typeNameUnknown(String)
}

public enum ElementKind: Codable, Equatable {
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

    public var rawValue: String {
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

public enum ElementChildrenFormat: String, Codable {
    case bullet
    case numbered
}

// Editable Text Data:
open class BeamElement: Codable, Identifiable, Hashable, ObservableObject, CustomDebugStringConvertible {
    @Published open private(set) var id = UUID() { didSet { change(.meta) } }
    @Published open var text = BeamText() { didSet { change(.text) } }
    @Published open var open = true { didSet { change(.meta) } }
    @Published open var children = [BeamElement]() { didSet { change(.tree) } }
    @Published open var readOnly = false { didSet { change(.meta) } }
    @Published open var score: Float = 0 { didSet { change(.meta) } }
    @Published open var creationDate = Date() { didSet { change(.meta) } }
    @Published open var updateDate = Date()
    @Published open var kind: ElementKind = .bullet { didSet { change(.meta) } }
    @Published open var childrenFormat: ElementChildrenFormat = .bullet { didSet { change(.meta) } }
    @Published open private(set) var textStats: ElementTextStats = ElementTextStats(wordsCount: 0)
    @Published open var query: String?

    open var note: BeamNote? {
        return parent?.note
    }

    public static let recursiveCoding = CodingUserInfoKey(rawValue: "recursiveCoding")!

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
        case textStats
    }

    public init() {
    }

    public init(_ text: String) {
        self.text = BeamText(text: text, attributes: [])
    }

    public init(_ text: BeamText) {
        self.text = text
    }

    public required init(from decoder: Decoder) throws {
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

        if container.contains(.query) {
            query = try container.decode(String.self, forKey: .query)
        }

        if container.contains(.textStats) {
            textStats = try container.decode(ElementTextStats.self, forKey: .textStats)
        } else {
            textStats = initializeTextStats()
        }
    }

    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let recursive = encoder.userInfo[Self.recursiveCoding] as? Bool ?? true

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(open, forKey: .open)
        try container.encode(readOnly, forKey: .readOnly)
        try container.encode(score, forKey: .score)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(textStats, forKey: .textStats)
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

    public func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?) -> BeamElement {
        let element = BeamElement()
        element.id = withNewId ? UUID() : id
        element.text = text
        element.open = open
        element.readOnly = readOnly
        element.score = score
        element.creationDate = creationDate
        for child in children {
            if selectedElements != nil {
                if let isSelected = selectedElements?.contains(child), isSelected {
                    element.children.append(child.deepCopy(withNewId: withNewId, selectedElements: selectedElements))
                } else {
                    element.children.append(contentsOf: child.deepCopy(withNewId: withNewId, selectedElements: selectedElements).children)
                }
            } else {
                element.children.append(child.deepCopy(withNewId: withNewId, selectedElements: selectedElements))
            }
        }
        element.kind = kind
        element.childrenFormat = childrenFormat
        element.query = query
        return element
    }

    open func clearChildren() {
        for c in children {
            c.parent = nil
        }
        children = []
    }

    open func removeChild(_ child: BeamElement) {
        guard let index = children.firstIndex(where: { (e) -> Bool in
            e === child
        }) else { return }
        children.remove(at: index)
        child.parent = nil
    }

    open func indexOfChild(_ child: BeamElement) -> Int? {
        return children.firstIndex(where: { (e) -> Bool in
            e === child
        })
    }

    open var indexInParent: Int? {
        return parent?.indexOfChild(self)
    }

    open func addChild(_ child: BeamElement) {
        insert(child, after: children.last) // append
    }

    open func insert(_ child: BeamElement, after: BeamElement?) {
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

    open func insert(_ child: BeamElement, at pos: Int) {
        if let oldParent = child.parent {
            oldParent.removeChild(child)
        }

        child.parent = self
        children.insert(child, at: min(children.count, pos))
    }

    open weak var parent: BeamElement?

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    open func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    @Published open var changed: (BeamElement, ChangeType)?
    open var changePropagationEnabled = true
    public enum ChangeType {
        case text, meta, tree
    }
    open func change(_ type: ChangeType) {
        guard changePropagationEnabled else { return }
        updateDate = Date()
        changed = (self, type)

        if type == .text || type == .tree {
            updateTextStats()
        }
        parent?.childChanged(self, type)
    }

    open func childChanged(_ child: BeamElement, _ type: ChangeType) {
        guard changePropagationEnabled else { return }
        updateDate = Date()
        changed = (child, type)
        if type == .text || type == .tree {
            updateTextStats()
        }
        parent?.childChanged(self, type)
    }

    open func findElement(_ id: UUID) -> BeamElement? {
        guard id != self.id else { return self }

        for c in children {
            if let result = c.findElement(id) {
                return result
            }
        }

        return nil
    }

    // TODO: use this for smart merging
    open func recursiveUpdate(other: BeamElement) {
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

    open var debugDescription: String {
        return "BeamElement(\(id) [\(children.count) children] \(kind) - \(childrenFormat) \(!open ? "[closed]" : ""): \(text.text)"
    }

    open var isHeader: Bool {
        switch kind {
        case .heading:
            return true
        default:
            return false
        }
    }

    open var flatElements: [BeamElement] {
        var elems = children
        for c in children {
            elems += c.flatElements
        }

        return elems
    }

    open func readLock() {
        note?.readLock()
    }

    open func readUnlock() {
        note?.readUnlock()
    }

    open func writeLock() {
        note?.writeLock()
    }

    open func writeUnlock() {
        note?.writeUnlock()
    }

    open var depth: Int {
        guard let depth = parent?.depth else { return 0 }
        return depth + 1
    }

    open func hasLinkToNote(named noteTitle: String) -> Bool {
        text.hasLinkToNote(named: noteTitle)
    }

    open func hasReferenceToNote(named noteTitle: String) -> Bool {
        text.hasReferenceToNote(titled: noteTitle)
    }

    open var outLinks: [String] {
        text.links + children.flatMap { $0.outLinks }
    }

    open func elementContainingLink(to link: String) -> BeamElement? {
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

    open func nextSibbling() -> BeamElement? {
        if let p = parent {
            let sibblings = p.children
            if let i = sibblings.firstIndex(of: self) {
                if sibblings.count > i + 1 {
                    return sibblings[i + 1]
                }
            }
        }
        return nil
    }

    open func previousSibbling() -> BeamElement? {
        if let p = parent {
            let sibblings = p.children
            if let i = sibblings.firstIndex(of: self) {
                if i > 0 {
                    return sibblings[i - 1]
                }
            }
        }
        return nil
    }

    open func highestNextSibbling() -> BeamElement? {
        if let nextSibbling = self.parent?.nextSibbling() {
            return nextSibbling
        }
        return self.parent?.highestNextSibbling()
    }

    open func deepestChildren() -> BeamElement? {
        if let n = children.last {
            return n.deepestChildren()
        }
        return self
    }

}

// MARK: - Text Stats
public struct ElementTextStats: Codable {
    public var wordsCount: Int
}

extension BeamElement {

    private func calculateWordsCount(includingChildren: Bool = true) -> Int {
        let str = text.text
        var count = str.numberOfWords
        if includingChildren {
            count += children.reduce(0, { (r, el) -> Int in
                return r + el.textStats.wordsCount
            })
        }
        return count
    }

    private func initializeTextStats() -> ElementTextStats {
        let wordsCount = self.calculateWordsCount()
        return ElementTextStats(wordsCount: wordsCount)
    }

    private func updateTextStats() {
        let wordsCount = self.calculateWordsCount()
        textStats.wordsCount = wordsCount
    }
}
