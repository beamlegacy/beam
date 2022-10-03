//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//

import Foundation
import Combine
import UUIDKit

public enum ElementKindError: Error {
    case typeNameUnknown(String)
    case failedToDecode(String, forKey: String)
}

public struct MediaDisplayInfos: Codable, Equatable {

    public init(height: Int? = nil, width: Int? = nil, displayRatio: Double? = nil) {
        self.height = height
        self.width = width
        self.displayRatio = displayRatio
    }

    public let height: Int?
    public let width: Int?
    public let displayRatio: Double?

    public var size: CGSize? {
        guard let height = height, let width = width else { return nil }
        return CGSize(width: width, height: height)
    }
}

public enum ElementKind: Codable, Equatable {
    /// Plain bullet
    case bullet
    /// Heading
    /// - Int: Level of identation
    case heading(Int)
    /// Quote
    /// - Int: Level of identation
    /// - SourceMetadata
    case quote(Int, origin: SourceMetadata? = nil)
    /// Check
    /// - Bool: True for checked, false for unchecked
    case check(Bool)
    /// Code block
    case code
    /// Dividing line
    case divider
    /// Image
    /// - UUID: ID of the image
    /// - SourceMetadata
    /// - displayInfos: Describes the image size and ratio
    case image(UUID, origin: SourceMetadata? = nil, displayInfos: MediaDisplayInfos)
    /// Embed
    /// - URL: url to embed
    /// - SourceMetadata
    /// - displayRatio
    case embed(URL, origin: SourceMetadata? = nil, displayInfos: MediaDisplayInfos)
    /// Block Reference
    /// - UUID: Target Note UUID
    /// - UUID: Target Element UUID
    /// - SourceMetadata
    case blockReference(UUID, UUID, origin: SourceMetadata? = nil)
    /// Daily Summary
    case dailySummary
    /// Tab Group reference
    case tabGroup(tabGroupId: UUID)

    public var isText: Bool {
        !isMedia
    }

    public var isMedia: Bool {
        switch self {
        case .image:
            return true
        case .embed:
            return true
        default:
            return false
        }
    }

    public var isEmbed: Bool {
        switch self {
        case .embed:
            return true
        default:
            return false
        }
    }

    public var isSpellCheckable: Bool {
        switch self {
        case .bullet, .heading, .quote, .check:
            return true
        default:
            return false
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case level
        case source
        case title
        case value
        case sizeRatio
        case height
        case width
        case displayInfos
        case sourceMetadata
        case tabGroupId
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
        case .divider:
            return "divider"
        case .image(let imageId, _, _):
            return "image '\(imageId)'"
        case .embed(let url, _, _):
            return "embed '\(url.absoluteString)'"
        case .blockReference(let note, let elementId, _):
            return "blockReference '\(note).\(elementId)'"
        case .dailySummary:
            return "dailySummary"
        case .tabGroup(let tabGroupId):
            return "tabGroup '\(tabGroupId)'"
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
            let level = try container.decode(Int.self, forKey: .level)

            if let sourceMetadata = try? container.decodeIfPresent(SourceMetadata.self, forKey: .source) {
                self = .quote(level, origin: sourceMetadata)
            } else {
                let source = try container.decode(String.self, forKey: .source)
                let title = try container.decode(String.self, forKey: .title)
                self = .quote(level, origin: SourceMetadata(string: source, title: title))
            }
        case "check":
            self = .check(try container.decode(Bool.self, forKey: .value))
        case "code":
            self = .code
        case "divider":
            self = .divider
        case "image":
            var displayInfos = MediaDisplayInfos()
            if let infos = try? container.decodeIfPresent(MediaDisplayInfos.self, forKey: .displayInfos) {
                displayInfos = infos
            } else if let sizeRatio = try? container.decodeIfPresent(Double.self, forKey: .sizeRatio) {
                displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: sizeRatio)
            }

            let sourceMetadata = try container.decodeIfPresent(SourceMetadata.self, forKey: .sourceMetadata)

            // Compatibility: We went through multiple strategies to decode the image source.
            // For backwards compatibility all strategies are still supported
            // V4
            if let imageId = try? container.decodeIfPresent(UUID.self, forKey: .source) {
                self = .image(imageId, origin: sourceMetadata, displayInfos: displayInfos)
                return
            }
            // V3
            if let sourceMetadata = try? container.decodeIfPresent(SourceMetadata.self, forKey: .source),
               case .local(let imageId) = sourceMetadata.origin {
                self = .image(imageId, displayInfos: displayInfos)
                return
            }
            // V2
            if let imageId = try? container.decodeIfPresent(UUID.self, forKey: .source) {
                self = .image(imageId, displayInfos: displayInfos)
                return
            }
            // V1
            if let imageIdString = try? container.decodeIfPresent(String.self, forKey: .source) {
                let imageId = UUID.v5(name: imageIdString, namespace: .url)
                self = .image(imageId, displayInfos: displayInfos)
                return
            } else {
                throw ElementKindError.failedToDecode(typeName, forKey: "source")
            }

        case "embed":
            var displayInfos = MediaDisplayInfos()
            if let infos = try? container.decodeIfPresent(MediaDisplayInfos.self, forKey: .displayInfos) {
                displayInfos = infos
            } else if let sizeRatio = try? container.decodeIfPresent(Double.self, forKey: .sizeRatio) {
                displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: sizeRatio)
            }

            // Compatibility: We went through multiple strategies to decode the embed source.
            // For backwards compatibility all strategies are still supported
            // V3
            if let urlString = try? container.decodeIfPresent(String.self, forKey: .source),
               let url = URL(string: urlString) {
                self = .embed(url, displayInfos: displayInfos)
                return
            }

            // V2
            if let sourceMetadata = try? container.decodeIfPresent(SourceMetadata.self, forKey: .source),
               case .remote(let url) = sourceMetadata.origin {
                self = .embed(url, displayInfos: displayInfos)
                return
            }

            // V1
            if let urlString = try? container.decodeIfPresent(String.self, forKey: .source),
                let url = URL(string: urlString) {
                self = .embed(url, displayInfos: displayInfos)
                return
            } else {
                throw ElementKindError.failedToDecode(typeName, forKey: "source")
            }

        case "blockReference":
            // Compatibility: We went through multiple strategies to decode the title UUID.
            // For backwards compatibility all strategies are still supported
            var noteID = UUID.null
            // V2
            if let id = try? container.decodeIfPresent(UUID.self, forKey: .title) {
                noteID = id
            }
            // V1
            if let idString = try container.decodeIfPresent(String.self, forKey: .title),
               let id = BeamNote.idForNoteNamed(idString) {
                noteID = id
            }

            // Compatibility: We went through multiple strategies to decode the source UUID.
            // For backwards compatibility all strategies are still supported
            var elementID = UUID.null
            // V2
            if let id = try? container.decodeIfPresent(UUID.self, forKey: .source) {
                elementID = id
            }
            // V1
            if let idString = try container.decodeIfPresent(String.self, forKey: .source),
               let id = UUID(uuidString: idString) {
                elementID = id
            }

            self = .blockReference(noteID, elementID)
        case "dailySummary":
            self = .dailySummary
        case "tabGroup":
            var tabGroupId = UUID.null
            if let id = try? container.decodeIfPresent(UUID.self, forKey: .tabGroupId) {
                tabGroupId = id
            }
            self = .tabGroup(tabGroupId: tabGroupId)
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
        case let .quote(level, sourceMetadata):
            try container.encode("quote", forKey: .type)
            try container.encode(level, forKey: .level)
            /// .source should describe a datasource, for additional source
            /// information use sourceMetadata instead
            /// TODO: Rename .source to be descriptive e.g. "imageId"
            try container.encode(sourceMetadata, forKey: .source)
            try container.encode(sourceMetadata, forKey: .sourceMetadata)
        case let .check(checked):
            try container.encode("check", forKey: .type)
            try container.encode(checked, forKey: .value)
        case .code:
            try container.encode("code", forKey: .type)
        case .divider:
            try container.encode("divider", forKey: .type)
        case let .image(imageId, sourceMetadata, displayInfo):
            try container.encode("image", forKey: .type)
            /// .source should describe a datasource, for additional source
            /// information use sourceMetadata instead
            /// TODO: Rename .source to be descriptive e.g. "imageId"
            try container.encode(imageId, forKey: .source)
            if let sourceMetadata = sourceMetadata {
                try container.encode(sourceMetadata, forKey: .sourceMetadata)
            }
            try container.encode(displayInfo, forKey: .displayInfos)
        case let .embed(url, sourceMetadata, displayInfo):
            try container.encode("embed", forKey: .type)
            /// .source should describe a datasource, for additional source
            /// information use sourceMetadata instead
            /// TODO: Rename .source to be descriptive e.g. "url"
            try container.encode(url, forKey: .source)
            if let sourceMetadata = sourceMetadata {
                try container.encode(sourceMetadata, forKey: .sourceMetadata)
            }
            try container.encode(displayInfo, forKey: .displayInfos)
        case let .blockReference(noteId, elementId, sourceMetadata):
            try container.encode("blockReference", forKey: .type)
            /// TODO: Rename .title to be descriptive e.g. "noteId"
            try container.encode(noteId, forKey: .title)
            /// .source should describe a datasource, for additional source
            /// information use sourceMetadata instead
            /// TODO: Rename .source to be descriptive e.g. "elementId"
            try container.encode(elementId, forKey: .source)
            if let sourceMetadata = sourceMetadata {
                try container.encode(sourceMetadata, forKey: .sourceMetadata)
            }
        case .dailySummary:
            try container.encode("dailySummary", forKey: .type)
        case .tabGroup(let tabGroupId):
            try container.encode("tabGroup", forKey: .type)            
            try container.encode(tabGroupId, forKey: .tabGroupId)
        }
    }
}

public enum ElementChildrenFormat: String, Codable {
    case bullet
    case numbered
}

// Editable Text Data:
open class BeamElement: Codable, Identifiable, Hashable, ObservableObject, CustomDebugStringConvertible {
    open var id = UUID() { didSet { change(.meta) } }
    @Published open var text = BeamText() { didSet { change(.text) } }
    @Published open var open = true { didSet { change(.meta) } }
    @Published open var collapsed = false { didSet { change(.meta) } }
    @Published open var children = [BeamElement]() { didSet { change(.tree) } }
    @Published open var readOnly = false { didSet { change(.meta) } }
    @Published open var creationDate = BeamDate.now { didSet { change(.meta) } }
    @Published open var updateDate = BeamDate.now
    @Published open var kind: ElementKind = .bullet { didSet { change(.meta) } }
    @Published open var childrenFormat: ElementChildrenFormat = .bullet { didSet { change(.meta) } }
    @Published open private(set) var textStats: ElementTextStats = ElementTextStats(wordsCount: 0)
    @Published open var query: String?
    internal var warmingUp = true

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
    public static let maxDepth = CodingUserInfoKey(rawValue: "maxDepth")!
    private static let depth = CodingUserInfoKey(rawValue: "depth")!
    private class DecodingDepth {
        var depth: Int = 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case open
        case collapsed
        case children
        case readOnly
        case creationDate
        case kind
        case childrenFormat
        case query
        case textStats
    }

    public init() {
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }
        updateTextStats()
    }

    public init(_ text: String) {
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }
        self.text = BeamText(text: text, attributes: [])
        updateTextStats()
    }

    public init(_ text: BeamText) {
        defer {
            changePropagationEnabled = true
            warmingUp = false
        }
        self.text = text
        updateTextStats()
    }

    public convenience init(tabGroupId: UUID) {
        self.init("TabGroupElement:\(tabGroupId)")
        kind = .tabGroup(tabGroupId: tabGroupId)
    }

    public required init(from decoder: Decoder) throws {
        let depth = decoder.userInfo[Self.depth] as? DecodingDepth
        let originalDepth = depth?.depth
        defer {
            changePropagationEnabled = true
            warmingUp = false
            if let originalDepth = originalDepth {
                depth?.depth = originalDepth
            }
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let recursive = decoder.userInfo[Self.recursiveCoding] as? Bool ?? true

        id = try container.decode(UUID.self, forKey: .id)
        do {
            text = try container.decode(BeamText.self, forKey: .text)
        } catch {
            let _text = (try? container.decode(String.self, forKey: .text)) ?? ""
            text = BeamText(text: _text, attributes: [])
        }
        open = (try? container.decode(Bool.self, forKey: .open)) ?? true
        collapsed = (try? container.decode(Bool.self, forKey: .collapsed)) ?? false
        if container.contains(.readOnly) {
            readOnly = try container.decode(Bool.self, forKey: .readOnly)
        }

        if container.contains(.creationDate) {
            creationDate = try container.decode(Date.self, forKey: .creationDate)
        }

        if recursive, container.contains(.children) {
            if let maxDepth = decoder.userInfo[Self.maxDepth] as? Int, let originalDepth = originalDepth
            {
                if originalDepth >= maxDepth {
                    return
                }
                depth?.depth = originalDepth + 1
            }

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
        if !text.isEmpty {
            try container.encode(text, forKey: .text)
        }
        if !open {
            try container.encode(open, forKey: .open)
        }
        if collapsed {
            try container.encode(collapsed, forKey: .collapsed)
        }
        if readOnly {
            try container.encode(readOnly, forKey: .readOnly)
        }

        try container.encode(creationDate, forKey: .creationDate)
        if textStats.wordsCount != 0 {
            try container.encode(textStats, forKey: .textStats)
        }
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

    private func removeUnselectedElementsFromTree(selectedElements: [BeamElement], keepFoldedChildren: Bool) {
        if keepFoldedChildren && !open {
            return
        }
        for child in children {
            child.removeUnselectedElementsFromTree(selectedElements: selectedElements, keepFoldedChildren: keepFoldedChildren)
            if !selectedElements.contains(child) {
                removeChild(child)
                for subChild in child.children where selectedElements.contains(subChild) {
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

    public var nonRecursiveCopy: BeamElement? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("Copy Error while encoding \(self)", category: .document)
            return nil
        }
        let decoder = BeamJSONDecoder()
        decoder.userInfo[BeamElement.recursiveCoding] = false
        return try? decoder.decode(Self.self, from: data)
    }

    public func deepCopy(withNewId: Bool, selectedElements: [BeamElement]?, includeFoldedChildren: Bool) -> BeamElement? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("DeepCopy Error while encoding \(self)", category: .document)
            return nil
        }
        let decoder = BeamJSONDecoder()
        guard let newElement = try? decoder.decode(Self.self, from: data) else {
            Logger.shared.logError("DeepCopy Error while decoding \(self)", category: .document)
            return nil
        }

        if let selectedElements = selectedElements {
            newElement.removeUnselectedElementsFromTree(selectedElements: selectedElements, keepFoldedChildren: includeFoldedChildren)
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

        dispatchChildRemoved(child)
    }

    open func dispatchChildRemoved(_ child: BeamElement) {
        guard changePropagationEnabled else { return }
        parent?.dispatchChildRemoved(child)
    }

    open func dispatchChildAdded(_ child: BeamElement) {
        guard changePropagationEnabled else { return }
        parent?.dispatchChildAdded(child)
    }

    open func indexOfChild(_ child: BeamElement) -> Int? {
        return children.firstIndex(where: { (e) -> Bool in
            e === child
        })
    }

    open var indexInParent: Int? {
        return parent?.indexOfChild(self)
    }

    /// Append child to end of BeamElement children array
    /// - Parameter child: BeamElement to add
    open func addChild(_ child: BeamElement) {
        insert(child, after: children.last) // append
    }

    /// Add array of BeamElements as children to BeamElement
    /// - Parameter children: Array of BeamElements
    open func addChildren(_ children: [BeamElement]) {
        for child in children {
            addChild(child)
        }
    }

    open func insert(_ child: BeamElement, after: BeamElement?) {
        guard child.parent != self else { return }

        let previousParent = child.parent
        defer {
            previousParent?.removeChild(child)
            dispatchChildAdded(child)
        }
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
        guard previousParent != self else {
            // This is the special case where we are moving a child inside the parent
            guard let index = child.indexInParent else { return }
            var newChildren = children
            newChildren.remove(at: index)
            newChildren.insert(child, at: min(children.count, pos))
            children = newChildren
            dispatchChildAdded(child)
            return
        }
        child.parent = self
        previousParent?.removeChild(child)
        children.insert(child, at: min(children.count, pos))
        dispatchChildAdded(child)
    }

    func checkHasParent() {
        hasParent = parent != nil
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
            guard parent != oldValue else { return }
            assert(parent !== self)
            checkHasParent()
        }
    }

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    open func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }

    open var isProxy: Bool { false }
    public let changed = PassthroughSubject<(BeamElement, ChangeType), Never>()
    public let treeChanged = PassthroughSubject<(BeamElement), Never>()
    public private(set) var lastChangeType: ChangeType?
    open var changePropagationEnabled = false
    public var recursiveChangePropagationEnabled: Bool {
        get {
            changePropagationEnabled
        }
        set {
            changePropagationEnabled = newValue
            for c in children {
                c.recursiveChangePropagationEnabled = newValue
            }
        }
    }
    public enum ChangeType {
        case text, meta, tree
    }
    open func change(_ type: ChangeType) {
        if !warmingUp {
            updateDate = BeamDate.now
            lastChangeType = type
        }

        if changePropagationEnabled {
            changed.send((self, type))
        }

        if type == .text || type == .tree {
            updateTextStats()
        }
        parent?.childChanged(self, type)

        parentChanged(self)
    }

    open func childChanged(_ child: BeamElement, _ type: ChangeType) {
        updateDate = BeamDate.now
        lastChangeType = type
        if changePropagationEnabled {
            changed.send((child, type))
        }
        if type == .text || type == .tree {
            updateTextStats()
        }
        parent?.childChanged(child, type)
    }

    open func parentChanged(_ parent: BeamElement) {
        guard changePropagationEnabled, !isProxy else { return }
        treeChanged.send(parent)
        for child in children {
            child.parentChanged(parent)
        }
    }

    open func findElement(_ id: UUID, ignoreClosed: Bool = false) -> BeamElement? {
        guard id != self.id else { return self }
        guard (!ignoreClosed || open) else { return nil }

        for c in children {
            if let result = c.findElement(id, ignoreClosed: ignoreClosed) {
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
                c.parent = self
            }
        }

        children = newChildren
    }

    open var debugDescription: String {
        return "BeamElement(\(id)) [\(children.count) children] \(kind) - \(childrenFormat) \(!open ? "[closed]" : ""): \(text.text)"
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

    /// Recursively search BeamElement links for matching link
    /// - Parameter link: link to search for
    /// - Returns: BeamElement containing matching link, nil if no element found
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

    /// Recursively search BeamElement sources for matching sourceLink
    /// - Parameter link: link to search for
    /// - Returns: BeamElement containing matching link, nil if no element found
    open func elementContainingSource(to link: String) -> BeamElement? {
        for source in text.sources {
            if case .remote(let url) = source.origin,
               url.absoluteString == link {
                return self
            }
        }

        for c in children {
            if let element = c.elementContainingSource(to: link) {
                return element
            }
        }

        return nil
    }

    /// Recursively search BeamElement text for matching string
    /// - Parameter someText: string to search for
    /// - Returns: BeamElement containing matching string, nil if no element found
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

    open func imageElements() -> [BeamElement] {
        var result: [BeamElement] = []

        switch self.kind {
        case .image:
            result.append(self)
        default: break
        }

        for c in children {
            let imageElements = c.imageElements()
            if !imageElements.isEmpty {
                result.append(contentsOf: imageElements)
            }
        }
        return result
    }

    open func nextElement() -> BeamElement? {
        if children.count > 0 {
            return children.first
        }

        if let n = nextSibbling() {
            return n
        }

        var p = parent
        var n: BeamElement?
        while n == nil && p != nil {
            n = p?.nextSibbling()
            p = p?.parent
        }

        if n !== self {
            return n
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

    /// Contains image url when a BeamElement's text contains a single image link
    open var imageLink: URL? {
        let imageLinks = text.links.compactMap({ link -> URL? in
            if let url = URL(string: link), url.isImageURL {
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

    public var richContent: [BeamElement] {

        var richContent: [BeamElement] = []

        switch self.kind {
        case .image:
            richContent.append(self)
        default:
            break
        }

        for c in children {
            richContent.append(contentsOf: c.richContent)
        }

        return richContent
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

    func updateTextStats() {
        let wordsCount = self.calculateWordsCount()
        textStats.wordsCount = wordsCount
    }

    public var indexPath: IndexPath {
        guard let parent = parent, let index = indexInParent else { return IndexPath() }
        return parent.indexPath.appending(index)
    }

    public func updateWith(_ other: BeamElement, allExistingElements: [UUID: BeamElement]) {
        self.text = other.text
        self.open = other.open
        self.collapsed = other.collapsed

        let newChildren = other.children.compactMap { element -> BeamElement? in
            // Try to keep the existing children
            let newElement: BeamElement
            if let existingChild = allExistingElements[element.id] {
                existingChild.updateWith(element, allExistingElements: allExistingElements)
                newElement = existingChild
            } else {
                newElement = element.deepCopy(withNewId: false, selectedElements: nil, includeFoldedChildren: true) ?? element
            }
            return newElement
        }
        self.replaceChildren(newChildren)
        self.readOnly = other.readOnly
        self.creationDate = other.creationDate
        self.updateDate = other.updateDate
        self.kind = other.kind
        self.childrenFormat = other.childrenFormat
    }

    func replaceChildren(_ newChildren: [BeamElement]) {
        let toUpdate = newChildren.filter { $0.parent != self }
        let toRemoveFromParent = [BeamElement: BeamElement?](uniqueKeysWithValues: toUpdate.map { ($0, $0.parent) })
        toUpdate.forEach { $0.parent = self }
        children = newChildren

        toRemoveFromParent.forEach { (child, previousParent) in
            previousParent?.removeChild(child)
            dispatchChildAdded(child)
        }

    }
}
