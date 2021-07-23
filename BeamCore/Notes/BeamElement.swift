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
    case check(Bool)
    case code
    case image(String)
    case embed(String)
    case blockReference(UUID, UUID)

    enum CodingKeys: String, CodingKey {
        case type
        case level
        case source
        case title
        case value
    }

    public var rawValue: String {
        switch self {
        case .bullet:
            return "bullet"
        case .heading(let level):
            return "heading \(level)"
        case .quote:
            return "quote"
        case .check(let checked):
            return "check \(checked)"
        case .code:
            return "code"
        case .image(let source):
            return "image '\(source)'"
        case .embed(let source):
            return "embed '\(source)'"
        case .blockReference(let note, let elementId):
            return "blockReference '\(note).\(elementId)'"
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
        case "check":
            self = .check(try container.decode(Bool.self, forKey: .value))
        case "code":
            self = .code

        case "image":
            self = .image(try container.decode(String.self, forKey: .source))

        case "embed":
            self = .embed(try container.decode(String.self, forKey: .source))
        case "blockReference":
            let noteID = try (try? container.decode(UUID.self, forKey: .title)) ?? BeamNote.idForNoteNamed(try container.decode(String.self, forKey: .title)) ?? UUID.null
            let elementID = try (try? container.decode(UUID.self, forKey: .source)) ?? UUID(uuidString: try container.decode(String.self, forKey: .source)) ?? UUID.null
            self = .blockReference(noteID, elementID)
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
        case let .check(checked):
            try container.encode("check", forKey: .type)
            try container.encode(checked, forKey: .value)
        case .code:
            try container.encode("code", forKey: .type)
        case let .image(source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        case let .embed(source):
            try container.encode("embed", forKey: .type)
            try container.encode(source, forKey: .source)
        case let .blockReference(title, source):
            try container.encode("blockReference", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(source, forKey: .source)
        }
    }
}

public enum ElementChildrenFormat: String, Codable {
    case bullet
    case numbered
}

// Editable Text Data:
open class BeamElement: Codable, Identifiable, Hashable, ObservableObject, CustomDebugStringConvertible {
    @Published open var id = UUID() { didSet { change(.meta) } }
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

    public func resetIds() {
        id = UUID()
        for c in children {
            c.resetIds()
        }
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

    private func removeUnselectedElementsFromTree(selectedElements: [BeamElement]) {
        for child in children {
            child.removeUnselectedElementsFromTree(selectedElements: selectedElements)
            if !selectedElements.contains(child) {
                removeChild(child)
                for subChild in child.children {
                    addChild(subChild)
                }
            }
        }
    }

    private func changeId() {
        id = UUID()
    }

    private func deepChangeId() {
        changeId()
        for child in children {
            child.deepChangeId()
        }
    }

    public func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?) -> BeamElement? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("DeepCopy Error while encoding \(self)", category: .document)
            return nil
        }
        let decoder = JSONDecoder()
        guard let newElement = try? decoder.decode(Self.self, from: data) else {
            Logger.shared.logError("DeepCopy Error while decoding \(self)", category: .document)
            return nil
        }

        if let selectedElements = selectedElements {
            newElement.removeUnselectedElementsFromTree(selectedElements: selectedElements)
        }

        if withNewId {
            newElement.deepChangeId()
        }

        return newElement
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
        // Only reset the child's parent if it was set to us, it may already have been reparented
        if child.parent === self {
            child.parent = nil
        }
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
        guard child.parent != self else { return }

        let previousParent = child.parent
        defer { previousParent?.removeChild(child) }
        child.parent = self
        guard let after = after, let index = indexOfChild(after) else {
            children.insert(child, at: 0)
            return
        }

        children.insert(child, at: index + 1)
    }

    open func insert(_ child: BeamElement, at pos: Int) {
        // The order is important here, we first add the child then remove it from the previous parent so that any event resulting from both elements' children change will not generate a temporary loss of the child anywhere else in the app.
        let previousParent = child.parent
        defer { previousParent?.removeChild(child) }
        child.parent = self
        children.insert(child, at: min(children.count, pos))
    }

    func checkHasParent() {
        let newValue = parent != nil
        guard newValue != hasParent else { return }
        hasParent = newValue
        checkHasNote()
    }

    func checkHasNote() {
        let newValue = parent?.hasNote ?? false
        guard newValue != hasNote else { return }
        hasNote = newValue
        for child in children {
            child.checkHasNote()
        }
    }

    @Published public var hasParent: Bool = false
    @Published public var hasNote: Bool = false

    open weak var parent: BeamElement? {
        didSet {
            checkHasParent()
        }
    }

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

    open func hasLinkToNote(id noteId: UUID) -> Bool {
        text.hasLinkToNote(id: noteId)
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

    open func elementContainingText(someText: String) -> BeamElement? {
        if text.text == someText {
            return self
        }

        for c in children {
            if let element = c.elementContainingText(someText: someText) {
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

    /// Utility to convert BeamElement containing a single embedable url to embed kind
   open func convertToEmbed() {
        let links = text.links
        if links.count == 1,
           let link = links.first,
           let url = URL(string: link),
           let embedUrl = url.embed {
            kind = .embed(embedUrl.absoluteString)
        }
    }

    /// Utility to convert BeamElement containing a single image url to image kind
    /// - Parameter id: Without id provided image link will be used instead
    open func convertToImage(_ id: String?) {
        if let url = imageLink {
            // Either use id if provided, else use image url
            let imageLocation = id ?? url.absoluteString
            kind = .image(imageLocation)
        }
    }

    /// Contains image url when a BeamElement's text contains a single image link
    open var imageLink: URL? {
        let imageLinks = text.links.compactMap({ link -> URL? in
            if let url = URL(string: link), url.isImage {
                return url
            }
            return nil
        })

        if let link = imageLinks.first {
            return link
        } else {
            return nil
        }
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
