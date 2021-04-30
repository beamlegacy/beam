//
//  BrowsingTree.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/01/2021.
//

import Foundation
import Combine

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
}

public struct ReadingEvent: Codable {
    public var type: ReadingEventType
    public var date: Date
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
    public var link: UInt64
    public var parent: BrowsingNode?
    public var tree: BrowsingTree! {
        didSet {
            for c in children {
                c.tree = tree
            }
        }
    }
    @Published public var events = [ReadingEvent(type: .creation, date: Date())]
    @Published public var children = [BrowsingNode]()
    public var score: Score { tree.scoreFor(link: link) }

    public var title: String {
        LinkStore.linkFor(link)?.title ?? "<???>"
    }
    public var url: String {
        LinkStore.linkFor(link)?.url ?? "<???>"
    }

    public func addEvent(_ type: ReadingEventType, date: Date = Date()) {
        events.append(ReadingEvent(type: type, date: date))
    }

    public init(tree: BrowsingTree, parent: BrowsingNode?, url: String, title: String?) {
        self.link = LinkStore.createIdFor(url, title: title)
        self.parent = parent
        self.tree = tree
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case link
        case events
        case children
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        link = try container.decode(UInt64.self, forKey: .link)
        if container.contains(.events) {
            events = try container.decode([ReadingEvent].self, forKey: .events)
        }
        if container.contains(.children) {
            children = try container.decode([BrowsingNode].self, forKey: .children)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(link, forKey: .link)
        if !events.isEmpty {
            try container.encode(events, forKey: .events)
        }
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
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
}

public class BrowsingTree: ObservableObject, Codable {
    @Published public private(set) var root: BrowsingNode!
    @Published public private(set) var current: BrowsingNode!

    public init(_ originalQuery: String?) {
        self.root = BrowsingNode(tree: self, parent: nil, url: originalQuery ?? "<???>", title: nil)
        self.current = root
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case root
        case scores
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        root = try container.decode(BrowsingNode.self, forKey: .root)
        current = root

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
    }

    /// Carefull this isn't a proper deepCopy
    /// BrowsingSessions contains BrowsingNode that are not properly cloned.
    /// This is used and needed for copy&paste atm
    public func deepCopy() -> BrowsingTree {
        let browsingTree = BrowsingTree("<???>")
        browsingTree.root = root
        browsingTree.current = root
        return browsingTree
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

    public func navigateTo(url link: String, title: String?, startReading: Bool) {
        guard current.link != LinkStore.getIdFor(link) else { return }
        Logger.shared.logInfo("navigateFrom \(currentLink) to \(link)", category: .web)
        current.addEvent(.navigateToLink)
        let node = BrowsingNode(tree: self, parent: current, url: link, title: title)
        current.children.append(node)
        current = node
        if startReading {
            current.addEvent(.startReading)
        }
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
