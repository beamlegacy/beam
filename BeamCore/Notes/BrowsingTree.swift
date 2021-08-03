//
//  BrowsingTree.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/01/2021.
//

// swiftlint:disable file_length

import Foundation
import Combine

public enum VisitType {
    case root
    case linkActivation
    case fromNote
    case searchBar
}

public enum BrowsingTreeOrigin: Codable {
    case searchBar(query: String)
    case searchFromNode(nodeText: String)
    case linkFromNote(noteName: String)
    case browsingNode(id: UUID)

    enum CodingKeys: CodingKey {
        case type, value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .searchBar(let query):
            try container.encode("searchBar", forKey: .type)
            try container.encode(query, forKey: .value)
        case .searchFromNode(let nodeText):
            try container.encode("searchFromNode", forKey: .type)
            try container.encode(nodeText, forKey: .value)
        case .linkFromNote(let noteName):
            try container.encode("linkFromNote", forKey: .type)
            try container.encode(noteName, forKey: .value)
        case .browsingNode(let id):
            try container.encode("browsingNode", forKey: .type)
            try container.encode(id, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "searchBar":
            self = .searchBar(query: try container.decode(String.self, forKey: .value))
        case "searchFromNode":
            self = .searchFromNode(nodeText: try container.decode(String.self, forKey: .value))
        case "linkFromNote":
            self = .linkFromNote(noteName: try container.decode(String.self, forKey: .value))
        case "browsingNode":
            self = .browsingNode(id: try container.decode(UUID.self, forKey: .value))
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

public struct ReadingEvent: Codable {
    public var type: ReadingEventType
    public var date: Date

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
    public var link: UInt64
    public var score: Score

    public static func == (lhs: ScoredLink, rhs: ScoredLink) -> Bool {
        lhs.link == rhs.link
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }
}

public class BrowsingNode: ObservableObject, Codable {
    public let id: UUID
    public var link: UInt64
    public let isLinkActivation: Bool
    public weak var parent: BrowsingNode?
    public weak var tree: BrowsingTree! {
        didSet {
            for c in children {
                c.tree = tree
            }
        }
    }
    @Published public var events = [ReadingEvent(type: .creation, date: Date())]
    @Published public var children = [BrowsingNode]()
    public var score: Score { tree.scoreFor(link: link) }
    public func longTermScoreApply(changes: (LongTermUrlScore) -> Void) {
        tree.longTermScoreStore?.apply(to: link, changes: changes)
    }

    public var title: String {
        LinkStore.linkFor(link)?.title ?? "<???>"
    }
    public var url: String {
        LinkStore.linkFor(link)?.url ?? "<???>"
    }
    private var isForeground: Bool = false
    private var lastStartReading: Date?

    private func readingTimeSinceLastEvent(date: Date) -> CFTimeInterval {
        guard let lastEvent = events.last else { return 0 }
        return lastEvent.readingTime(isForeground: isForeground, toDate: date)
    }

    public func addEvent(_ type: ReadingEventType, date: Date = Date()) {
        let incrementalReadingTime = readingTimeSinceLastEvent(date: date)
        score.readingTimeToLastEvent += incrementalReadingTime
        longTermScoreApply { $0.readingTimeToLastEvent += incrementalReadingTime }
        let event = ReadingEvent(type: type, date: date)
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
                tree.frecencyScorer?.update(urlId: link, value: readingTime, visitType: visitType, date: lastStartReading, paramKey: .readingTime30d0)
                self.lastStartReading = nil
            }
        }
        score.isForeground = isForeground
    }
    var visitType: VisitType {
        guard let parent = parent else { return .root }
        if parent.id == tree.root.id {
            switch tree.origin {
            case .browsingNode: return .linkActivation
            case .searchFromNode: return .fromNote
            case .linkFromNote: return .fromNote
            case .searchBar: return .searchBar
            }
        }
        return isLinkActivation ? .linkActivation : .searchBar
    }

    public init(tree: BrowsingTree, parent: BrowsingNode?, url: String, title: String?, isLinkActivation: Bool) {
        id = UUID()
        self.link = LinkStore.createIdFor(url, title: title)
        self.parent = parent
        self.tree = tree
        self.isLinkActivation = isLinkActivation
        let creationDate = events.first?.date
        score.lastCreationDate = creationDate
        longTermScoreApply { $0.lastCreationDate = creationDate }
        if let creationDate = creationDate {
            tree.frecencyScorer?.update(urlId: link, value: 1, visitType: visitType, date: creationDate, paramKey: .visit30d0)
        }
        longTermScoreApply { $0.visitCount += 1 }
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case link
        case events
        case children
        case id
        case isLinkActivation
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        link = try container.decode(UInt64.self, forKey: .link)
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
        try container.encode(id, forKey: .id)
        if !events.isEmpty {
            try container.encode(events, forKey: .events)
        }
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
    }

    public func deepCopy() -> BrowsingNode? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            Logger.shared.logError("DeepCopy Error while encoding \(self)", category: .document)
            return nil
        }

        let decoder = JSONDecoder()
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
}

private let defaultOrigin = BrowsingTreeOrigin.searchBar(query: "<???>")

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
        self.root = BrowsingNode(tree: self, parent: nil, url: "<???>", title: nil, isLinkActivation: false)
        self.current = root
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case root
        case scores
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

        if container.contains(.scores) {
            scores = try container.decode([UInt64: Score].self, forKey: .scores)
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

        let decoder = JSONDecoder()
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
        LinkStore.linkFor(current.link)?.url ?? "<???>"
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
        guard current.link != LinkStore.getIdFor(link) else { return }
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

    public var links: Set<UInt64> {
        var set = Set<UInt64>()

        root.visit { link in
            set.insert(link.link)
        }

        return set
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

    var scores = [UInt64: Score]()
    func scoreFor(link: UInt64) -> Score {
        guard let score = scores[link] else {
            let score = Score()
            scores[link] = score
            return score
        }
        return score
    }
}
