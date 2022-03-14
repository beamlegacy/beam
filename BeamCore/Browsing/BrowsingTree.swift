//
//  BrowsingTree.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/01/2021.
//

// swiftlint:disable file_length

import Foundation
import Combine

public indirect enum BrowsingTreeOrigin: Codable, Equatable {
    case searchBar(query: String?, referringRootId: UUID?)
    case searchFromNode(nodeText: String?)
    case linkFromNote(noteName: String?)
    case browsingNode(id: UUID, pageLoadId: UUID?, rootOrigin: BrowsingTreeOrigin?, rootId: UUID?) //following a cmd + click on link
    case historyImport(sourceBrowser: BrowserType)

    public var rootOrigin: BrowsingTreeOrigin? {
        switch self {
        case let .browsingNode(_, _, origin, _): return origin
        default: return self
        }
    }
    public var anonymized: BrowsingTreeOrigin {
        switch self {
        case .searchBar(query: _, referringRootId: let id): return .searchBar(query: nil, referringRootId: id)
        case .searchFromNode: return .searchFromNode(nodeText: nil)
        case .linkFromNote: return .linkFromNote(noteName: nil)
        case .browsingNode(id: let id, pageLoadId: let pageLoadId, rootOrigin: let rootOrigin, rootId: let rootId):
            return .browsingNode(id: id, pageLoadId: pageLoadId, rootOrigin: rootOrigin?.anonymized, rootId: rootId)
        case .historyImport: return self
        }
    }

    enum CodingKeys: CodingKey {
        case type, value, rootOrigin, pageLoadId, rootId, referringRootId
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .searchBar(let query, let referringRootId):
            try container.encode("searchBar", forKey: .type)
            try container.encode(query, forKey: .value)
            if let referringRootId = referringRootId {
                try container.encode(referringRootId, forKey: .referringRootId)
            }
        case .searchFromNode(let nodeText):
            try container.encode("searchFromNode", forKey: .type)
            try container.encode(nodeText, forKey: .value)
        case .linkFromNote(let noteName):
            try container.encode("linkFromNote", forKey: .type)
            try container.encode(noteName, forKey: .value)
        case .browsingNode(let id, let pageLoadId, let rootOrigin, let rootId):
            try container.encode("browsingNode", forKey: .type)
            if let pageLoadId = pageLoadId {
                try container.encode(pageLoadId, forKey: .pageLoadId)
            }
            try container.encode(id, forKey: .value)
            if let rootOrigin = rootOrigin {
                try container.encode(rootOrigin, forKey: .rootOrigin)
            }
            if let rootId = rootId {
                try container.encode(rootId, forKey: .rootId)
            }
        case .historyImport(let sourceBrowser):
            try container.encode("historyImport", forKey: .type)
            try container.encode(sourceBrowser.rawValue, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "searchBar":
            self = .searchBar(query: try? container.decode(String.self, forKey: .value),
                              referringRootId: try? container.decodeIfPresent(UUID.self, forKey: .referringRootId))
        case "searchFromNode":
            self = .searchFromNode(nodeText: try? container.decode(String.self, forKey: .value))
        case "linkFromNote":
            self = .linkFromNote(noteName: try? container.decode(String.self, forKey: .value))
        case "browsingNode":
            self = .browsingNode(
                id: try container.decode(UUID.self, forKey: .value),
                pageLoadId: try? container.decode(UUID.self, forKey: .pageLoadId),
                rootOrigin: try? container.decode(BrowsingTreeOrigin.self, forKey: .rootOrigin),
                rootId: try? container.decodeIfPresent(UUID.self, forKey: .rootId))
        case "historyImport":
            self = .historyImport(sourceBrowser: try container.decode(BrowserType.self, forKey: .value))
        default:
            throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: container.codingPath,
                            debugDescription: "Unabled to decode enum. Case \(type) does not exist."
                        )
            )
        }
    }
}

public enum ReadingEventType: String, Codable {
    case creation
    case startReading
    case navigateToLink
    case closeTab
    case switchToBackground
    case exitBackward
    case exitForward
    case switchToOtherTab
    case switchToCard
    case switchToJournal
    case switchToNewSearch
    case openLinkInNewTab
    case searchBarNavigation
    case closeApp
    case destinationNoteChange
}

let ExitForegroundEventTypes: Set = [
    ReadingEventType.exitForward,
    ReadingEventType.navigateToLink,
    ReadingEventType.searchBarNavigation,
    ReadingEventType.closeTab,
    ReadingEventType.switchToBackground,
    ReadingEventType.exitBackward,
    ReadingEventType.switchToOtherTab,
    ReadingEventType.switchToCard,
    ReadingEventType.switchToJournal,
    ReadingEventType.switchToNewSearch,
    ReadingEventType.closeApp
]

let ClosingEventTypes: Set = [
    ReadingEventType.navigateToLink,
    ReadingEventType.closeTab,
    ReadingEventType.exitBackward,
    ReadingEventType.exitForward,
    ReadingEventType.searchBarNavigation
]

public struct ReadingEvent: Codable, Equatable {
    public var id: UUID? = UUID()
    public var type: ReadingEventType
    public var date: Date
    public var webSessionId: UUID?
    public var pageLoadId: UUID? = UUID() //Id renewing each time a browsing node is revisited when forward/backward navigating

    public var isForegroundExiting: Bool {
        ExitForegroundEventTypes.contains(type)
    }
    public var isForegroundEntering: Bool {
        type == ReadingEventType.startReading
    }
    public var isClosing: Bool {
        ClosingEventTypes.contains(type)
    }
    public func readingTime(isForeground: Bool, toDate: Date) -> CFTimeInterval {
        return isForeground ? toDate.timeIntervalSince(date) : 0
    }
}

public struct ScoredLink: Hashable {
    public var link: UUID
    public var score: Score

    public static func == (lhs: ScoredLink, rhs: ScoredLink) -> Bool {
        lhs.link == rhs.link
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }
}

public struct ForegroundSegment {
    public var start: Date
    public var end: Date
    public var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

public class BrowsingNode: ObservableObject, Codable {
    public let id: UUID
    public var legacy = false
    public var link: UUID
    public let isLinkActivation: Bool
    public weak var parent: BrowsingNode?
    public weak var tree: BrowsingTree! {
        didSet {
            for c in children {
                c.tree = tree
            }
        }
    }
    @Published public var events: [ReadingEvent] = []
    @Published public var children = [BrowsingNode]()
    public var score: Score { tree.scoreFor(link: link) }
    public func longTermScoreApply(changes: (LongTermUrlScore) -> Void) {
        tree.longTermScoreStore?.apply(to: link, changes: changes)
    }

    public var title: String {
        LinkStore.linkFor(link)?.title ?? "<???>"
    }
    public var url: String {
        LinkStore.linkFor(link)?.url ?? Link.missing.url
    }
    private var isForeground: Bool = false
    private var lastStartReading: Date?

    private func readingTimeSinceLastEvent(date: Date) -> CFTimeInterval {
        guard let lastEvent = events.last else { return 0 }
        return lastEvent.readingTime(isForeground: isForeground, toDate: date)
    }
    private var pageLoadId: UUID {
        guard let lastEvent = events.last else { return UUID() }
        return lastEvent.isClosing ? UUID() : (lastEvent.pageLoadId ?? UUID())
    }

    public func addEvent(_ type: ReadingEventType, date: Date = BeamDate.now, webSessionId: UUID = WebSessionnizer.shared.sessionId) {
        if let previousEvent = events.last,
           date.timeIntervalSince(previousEvent.date) < 0 {
            Logger.shared.logWarning("⚠️ Pair of reading event dates in wrong order for url: \(url) - previous: \(previousEvent.date), \(previousEvent.type) - current: \(date), \(type)", category: .web)
        }

        let incrementalReadingTime = readingTimeSinceLastEvent(date: date)
        score.readingTimeToLastEvent += incrementalReadingTime
        longTermScoreApply { $0.readingTimeToLastEvent += incrementalReadingTime }
        let event = ReadingEvent(type: type, date: date, webSessionId: webSessionId, pageLoadId: pageLoadId)
        events.append(event)
        score.lastEvent = event
        if event.isForegroundEntering {
            isForeground = true
            lastStartReading = lastStartReading ?? date
        }
        if event.isForegroundExiting {
            isForeground = false
            if let lastStartReading = lastStartReading {
                let readingTime = Float(date.timeIntervalSince(lastStartReading))
                if let scorer = tree.frecencyScorer {
                    if readingTime >= 0 {
                        scorer.update(id: link, value: readingTime, eventType: visitType, date: lastStartReading, paramKey: .webReadingTime30d0)
                        Self.updateDomainFrecency(scorer: scorer, id: link, value: readingTime, date: lastStartReading, paramKey: .webReadingTime30d0)
                    } else {
                        Logger.shared.logWarning("⚠️ Negative reading time encountered for url: \(url) - start time: \(lastStartReading) - end time: \(date)", category: .web)
                    }
                }
                self.lastStartReading = nil
            }
        }
        score.isForeground = isForeground
    }
    public var visitType: FrecencyEventType {
        guard let parent = parent else { return .webRoot }
        if parent.id == tree.root.id {
            switch tree.origin {
            case .browsingNode: return .webLinkActivation
            case .searchFromNode: return .webFromNote
            case .linkFromNote: return .webFromNote
            case .searchBar: return .webSearchBar
            case .historyImport: return .webSearchBar
            }
        }
        return isLinkActivation ? .webLinkActivation : .webSearchBar
    }

    private static func updateDomainFrecency(scorer: FrecencyScorer, id: UUID, value: Float, date: Date, paramKey: FrecencyParamKey) {
        let isDomain = LinkStore.shared.isDomain(id: id)
        if !isDomain,
            let domainId = LinkStore.shared.getDomainId(id: id) {
            scorer.update(id: domainId, value: value, eventType: .webDomainIncrement, date: date, paramKey: paramKey)
        }
    }

    public init(tree: BrowsingTree, parent: BrowsingNode?, url: String, title: String?, isLinkActivation: Bool, date: Date = BeamDate.now) {
        id = UUID()
        self.link = LinkStore.visit(url, title: title).id
        self.parent = parent
        self.tree = tree
        self.isLinkActivation = isLinkActivation
        self.events = [ReadingEvent(type: .creation, date: date, webSessionId: WebSessionnizer.shared.sessionId, pageLoadId: UUID())]
        score.lastCreationDate = date
        longTermScoreApply { $0.lastCreationDate = date }
        if let scorer = tree.frecencyScorer {
            scorer.update(id: link, value: 1, eventType: visitType, date: date, paramKey: .webVisit30d0)
            Self.updateDomainFrecency(scorer: scorer, id: link, value: 1, date: date, paramKey: .webVisit30d0)
            }
        longTermScoreApply { $0.visitCount += 1 }
    }
    init(id: UUID, link: UUID, events: [ReadingEvent], legacy: Bool, isLinkActivation: Bool) {
        self.id = id
        self.link = link
        self.events = events
        self.legacy = legacy
        self.isLinkActivation = isLinkActivation
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case link
        case legacy
        case events
        case children
        case id
        case isLinkActivation
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // TODO: Remove legacyLink handling when all legacy trees have been deleted
        if (try? container.decode(UInt64.self, forKey: .link)) != nil {
            legacy = true
            link = UUID()
        } else {
            legacy = (try? container.decode(Bool.self, forKey: .legacy)) ?? false
            link = try container.decode(UUID.self, forKey: .link)
        }
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        isLinkActivation = (try? container.decode(Bool.self, forKey: .isLinkActivation)) ?? false
        if container.contains(.events) {
            events = try container.decode([ReadingEvent].self, forKey: .events)
        }
        if container.contains(.children) {
            children = try container.decode([BrowsingNode].self, forKey: .children)
            for child in children {
                child.parent = self
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(link, forKey: .link)
        try container.encode(legacy, forKey: .legacy)
        try container.encode(id, forKey: .id)
        if !events.isEmpty {
            try container.encode(events, forKey: .events)
        }
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
        try container.encode(isLinkActivation, forKey: .isLinkActivation)
    }

    public func deepCopy() -> BrowsingNode? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("DeepCopy Error while encoding \(self)", category: .document)
            return nil
        }

        let decoder = BeamJSONDecoder()
        guard let newBrowsingNode = try? decoder.decode(Self.self, from: data) else {
            Logger.shared.logError("DeepCopy Error while decoding \(self)", category: .document)
            return nil
        }

        return newBrowsingNode
    }

    public func visit(_ block: @escaping (BrowsingNode) -> Void) {
        block(self)
        for c in children {
            c.visit(block)
        }
    }

    public func dump(level: Int = 0) {
        let tabs = String.tabs(level)

        Logger.shared.logDebug(tabs + "'\(title)' / '\(url)'")
        for child in children {
            child.dump(level: level + 1)
        }
    }

    var indexPath: IndexPath {
        var path = [Int]()
        var previous: BrowsingNode? = self
        var current = parent
        while current != nil {
            guard let index = current?.children.firstIndex(where: { node in
                node === previous
            }) else { return IndexPath() }
            path.insert(index, at: 0)
            previous = current
            current = previous?.parent
        }
        return IndexPath(indexes: path)
    }

    func childWithPath(_ path: IndexPath) -> BrowsingNode? {
        guard let index = path.first else { return nil }
        let child = children[index]
        if path.count == 1 {
            return child
        }
        return child.childWithPath(path.suffix(path.count - 1))
    }
    public var foregroundSegments: [ForegroundSegment] {
        var segments = [ForegroundSegment]()
        var start: Date?
        for event in events {
            if event.type == .startReading, start == nil {
                start = event.date
            }
            if event.isForegroundExiting, let startUnwrapped = start {
                segments.append(ForegroundSegment(start: startUnwrapped, end: event.date))
                start = nil
            }
        }
        return segments
    }
}

private let defaultOrigin = BrowsingTreeOrigin.searchBar(query: "<???>", referringRootId: nil)

public class BrowsingTree: ObservableObject, Codable, BrowsingSession {
    @Published public private(set) var root: BrowsingNode!
    @Published public private(set) var current: BrowsingNode!

    public let origin: BrowsingTreeOrigin
    var frecencyScorer: FrecencyScorer?
    var longTermScoreStore: LongTermUrlScoreStoreProtocol?

    public init(_ origin: BrowsingTreeOrigin?, frecencyScorer: FrecencyScorer? = nil, longTermScoreStore: LongTermUrlScoreStoreProtocol? = nil) {
        self.origin = origin ?? defaultOrigin
        self.frecencyScorer = frecencyScorer
        self.longTermScoreStore = longTermScoreStore
        self.root = BrowsingNode(tree: self, parent: nil, url: Link.missing.url, title: nil, isLinkActivation: false)
        self.current = root
    }
    init(root: BrowsingNode, current: BrowsingNode, scores: [UUID: Score], origin: BrowsingTreeOrigin) {
        self.root = root
        self.current = current
        self.scores = scores
        self.origin = origin
    }
    public var anonymized: BrowsingTree {
        BrowsingTree(root: root, current: current, scores: scores, origin: origin.anonymized)
    }

    public init(origin: BrowsingTreeOrigin, root: BrowsingNode, current: BrowsingNode, scores: [UUID: Score]) {
        self.origin = origin
        self.root = root
        self.scores = scores
        self.current = current
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case root
        case scores
        case legacyScores
        case origin
        case currentPath
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        origin = (try? container.decode(BrowsingTreeOrigin.self, forKey: .origin)) ?? defaultOrigin
        root = try container.decode(BrowsingNode.self, forKey: .root)
        if let indexPath = try? container.decode(IndexPath.self, forKey: .currentPath), !indexPath.isEmpty {
            current = root.childWithPath(indexPath)
        } else {
            current = root
        }

        scoreStep: if container.contains(.scores) {
            guard let scores = try? container.decode([UUID: Score].self, forKey: .scores) else { break scoreStep }
            self.scores = scores
        } else {
            // old version, let's fish for them:
            root.visit { link in
                self.scores[link.link] = Score()
            }
        }
        root.tree = self
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(root, forKey: .root)
        try container.encode(scores, forKey: .scores)
        try container.encode(origin, forKey: .origin)
        try container.encode(current.indexPath, forKey: .currentPath)
    }

    public func deepCopy() -> BrowsingTree? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("DeepCopy Error while encoding \(self)", category: .document)
            return nil
        }

        let decoder = BeamJSONDecoder()
        guard let newBrowsingTree = try? decoder.decode(Self.self, from: data) else {
            Logger.shared.logError("DeepCopy Error while decoding \(self)", category: .document)
            return nil
        }
        return newBrowsingTree
    }

    public func startReading() {
        current.addEvent(.startReading)
    }

    public var currentLink: String {
        LinkStore.linkFor(current.link)?.url ?? Link.missing.url
    }

    @discardableResult
    public func goBack() -> BrowsingNode {
        guard let parent = current.parent else { return current }
        current.addEvent(.exitBackward)
        current = parent
        current.addEvent(.startReading)
        Logger.shared.logInfo("goBack to \(currentLink)", category: .web)
        return current
    }

    @discardableResult
    public func goForward() -> BrowsingNode {
        current.addEvent(.exitForward)
        guard let lastChild = current.children.last else { return current }
        current = lastChild
        current.addEvent(.startReading)
        Logger.shared.logInfo("goForward to \(currentLink)", category: .web)
        return current
    }

    public func navigateTo(url link: String, title: String?, startReading: Bool, isLinkActivation: Bool, readCount: Int) {
        guard current.link != LinkStore.getOrCreateIdFor(link) else { return }
        Logger.shared.logInfo("navigateFrom \(currentLink) to \(link)", category: .web)
        let event = isLinkActivation ? ReadingEventType.navigateToLink : ReadingEventType.searchBarNavigation
        current.addEvent(event)
        let node = BrowsingNode(tree: self, parent: current, url: link, title: title, isLinkActivation: isLinkActivation)
        current.children.append(node)
        current = node
        if startReading {
            current.addEvent(.startReading)
        }
        current.score.textAmount = readCount
        current.longTermScoreApply { $0.textAmount = readCount }
        Logger.shared.logInfo("current now is \(currentLink)", category: .web)
    }
    //to use only in history import (prevent deep nesting then impossible to encode)
    public func addChildToRoot(url link: String, title: String?, date: Date) {
        guard case .historyImport = origin else { return }
        let node = BrowsingNode(tree: self, parent: root, url: link, title: title, isLinkActivation: true, date: date)
        root.children.append(node)
        current = node
    }

    public func closeTab() {
        current.addEvent(.closeTab)
        Logger.shared.logInfo("Close tab \(currentLink)", category: .web)
    }

    public func switchToBackground() {
        current.addEvent(.switchToBackground)
    }

    public func switchToOtherTab() {
        current.addEvent(.switchToOtherTab)
    }

    public func switchToCard() {
        current.addEvent(.switchToCard)
    }

    public func switchToJournal() {
        current.addEvent(.switchToJournal)
    }

    public func switchToNewSearch() {
        current.addEvent(.switchToNewSearch)
    }

    public func openLinkInNewTab() {
        current.addEvent(.openLinkInNewTab)
    }

    public func closeApp() {
        current.addEvent(.closeApp)
    }

    public func destinationNoteChange() {
        current.addEvent(.destinationNoteChange)
    }

    public var links: Set<UUID> {
        var set = Set<UUID>()

        root.visit { link in
            set.insert(link.link)
        }

        return set
    }
    public var idUrlMapping: [UUID: String] {
        var mapping = [UUID: String]()
        links.forEach {
            mapping[$0] = (LinkStore.linkFor($0)?.url ?? Link.missing.url)
        }
        return mapping
    }

    public var scoredLinks: Set<ScoredLink> {
        var set = Set<ScoredLink>()

        root.visit { link in
            set.insert(ScoredLink(link: link.link, score: link.score))
        }

        return set
    }

    public var sortedLinks: [ScoredLink] {
        scoredLinks.sorted { left, right -> Bool in
            left.score.score < right.score.score
        }
    }

    public func dump() {
        Logger.shared.logDebug("BrowsingTree - current = '\(current.title)' / \(current.url)")
        root.dump()
    }

    var scores = [UUID: Score]()
    func scoreFor(link: UUID) -> Score {
        guard let score = scores[link] else {
            let score = Score()
            scores[link] = score
            return score
        }
        return score
    }
    public var rootId: UUID? { root?.id }

    // MARK: - Conversion from/to serializable format
    public convenience init?(flattenedTree: FlatennedBrowsingTree) {
        let flattenedTreeCopy = flattenedTree.copy //avoids mutating original flattenedTree
        guard let root = flattenedTreeCopy.root else { return nil }
        let current = flattenedTreeCopy.current ?? root
        self.init(origin: flattenedTreeCopy.origin, root: root, current: current, scores: flattenedTreeCopy.scores)
        for (node, parentIndex) in zip(flattenedTreeCopy.nodes, flattenedTreeCopy.parentIndexes) {
            if let parentIndex = parentIndex,
               let parentNode = flattenedTreeCopy.node(index: parentIndex) {
                parentNode.children.append(node)
                node.parent = parentNode
            }
        }
        root.tree = self
    }

    public var flattened: FlatennedBrowsingTree {
        var nodes = [BrowsingNode]()
        var parentIndexes = [Int?]()
        var currentIndex: Int = 0
        var nodesToVisit: [(BrowsingNode, Int?)] = [(root, nil)]
        while !nodesToVisit.isEmpty {
            let (node, parentIndex) = nodesToVisit.removeLast()
            let index = nodes.count
            if node.id == current.id { currentIndex = index }
            nodes.append(node.serializable)
            parentIndexes.append(parentIndex)
            nodesToVisit.append(contentsOf: node.children.reversed().map { ($0, index) })
        }
        return FlatennedBrowsingTree(currentIndex: currentIndex, scores: scores, origin: origin, nodes: nodes, parentIndexes: parentIndexes)
    }
}
