//
//  BrowsingTree.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/01/2021.
//

import Foundation
import Combine

enum ReadingEventType: String, Codable {
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
}

struct ReadingEvent: Codable {
    var type: ReadingEventType
    var date: Date
}

struct ScoredLink: Hashable {
    var link: UInt64
    var score: Score

    static func == (lhs: ScoredLink, rhs: ScoredLink) -> Bool {
        lhs.link == rhs.link
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }
}

class BrowsingNode: ObservableObject, Codable {
    var link: UInt64
    var parent: BrowsingNode?
    var tree: BrowsingTree! {
        didSet {
            for c in children {
                c.tree = tree
            }
        }
    }
    @Published var events = [ReadingEvent(type: .creation, date: Date())]
    @Published var children = [BrowsingNode]()
    var score: Score { tree.scoreFor(link: link) }

    var title: String {
        LinkStore.linkFor(link)?.title ?? "<???>"
    }
    var url: String {
        LinkStore.linkFor(link)?.url ?? "<???>"
    }

    func addEvent(_ type: ReadingEventType, date: Date = Date()) {
        events.append(ReadingEvent(type: type, date: date))
    }

    init(tree: BrowsingTree, parent: BrowsingNode?, url: String, title: String?) {
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

    required init(from decoder: Decoder) throws {
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

    func visit(_ block: @escaping (BrowsingNode) -> Void) {
        block(self)
        for c in children {
            c.visit(block)
        }
    }

    func dump(level: Int = 0) {
        let tabs = String.tabs(level)

        print(tabs + "'\(title)' / '\(url)'")
        for child in children {
            child.dump(level: level + 1)
        }
    }
}

class BrowsingTree: ObservableObject, Codable {
    @Published public private(set) var root: BrowsingNode!
    @Published public private(set) var current: BrowsingNode!

    init(_ originalQuery: String?) {
        self.root = BrowsingNode(tree: self, parent: nil, url: originalQuery ?? "<???>", title: nil)
        self.current = root
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case root
        case scores
    }

    required init(from decoder: Decoder) throws {
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

    func startReading() {
        current.addEvent(.startReading)
    }

    var currentLink: String {
        LinkStore.linkFor(current.link)?.url ?? "<???>"
    }

    @discardableResult
    func goBack() -> BrowsingNode {
        guard let parent = current.parent else { return current }
        current.addEvent(.exitBackward)
        current = parent
        current.addEvent(.startReading)
        Logger.shared.logInfo("goBack to \(currentLink)", category: .web)
        return current
    }

    @discardableResult
    func goForward() -> BrowsingNode {
        current.addEvent(.exitForward)
        guard let lastChild = current.children.last else { return current }
        current = lastChild
        current.addEvent(.startReading)
        Logger.shared.logInfo("goForward to \(currentLink)", category: .web)
        return current
    }

    func navigateTo(url link: String, title: String?) {
        guard current.link != LinkStore.getIdFor(link) else { return }
        Logger.shared.logInfo("navigateFrom \(currentLink) to \(link)", category: .web)
        current.addEvent(.navigateToLink)
        let node = BrowsingNode(tree: self, parent: current, url: link, title: title)
        current.children.append(node)
        current = node
        current.addEvent(.startReading)
        Logger.shared.logInfo("current now is \(currentLink)", category: .web)
    }

    func closeTab() {
        current.addEvent(.closeTab)
        Logger.shared.logInfo("Close tab \(currentLink)", category: .web)
    }

    func switchToBackground() {
        current.addEvent(.switchToBackground)
    }

    func switchToOtherTab() {
        current.addEvent(.switchToOtherTab)
    }

    func switchToCard() {
        current.addEvent(.switchToCard)
    }

    func switchToNewSearch() {
        current.addEvent(.switchToNewSearch)
    }

    var links: Set<UInt64> {
        var set = Set<UInt64>()

        root.visit { link in
            set.insert(link.link)
        }

        return set
    }

    var scoredLinks: Set<ScoredLink> {
        var set = Set<ScoredLink>()

        root.visit { link in
            set.insert(ScoredLink(link: link.link, score: link.score))
        }

        return set
    }

    var sortedLinks: [ScoredLink] {
        scoredLinks.sorted { left, right -> Bool in
            left.score.score < right.score.score
        }
    }

    func dump() {
        print("BrowsingTree - current = '\(current.title)' / \(current.url)")
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
