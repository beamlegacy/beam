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

class BrowsingNode: ObservableObject, Codable {
    var link: UInt64
    var parent: BrowsingNode?
    @Published var events = [ReadingEvent(type: .creation, date: Date())]
    @Published var children = [BrowsingNode]()

    func addEvent(_ type: ReadingEventType, date: Date = Date()) {
        events.append(ReadingEvent(type: type, date: date))
    }

    init(parent: BrowsingNode?, url: String, title: String?) {
        self.link = LinkStore.createIdFor(url, title: title)
        self.parent = parent
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
}

class BrowsingTree: ObservableObject, Codable {
    @Published var root: BrowsingNode
    @Published var current: BrowsingNode!

    init(_ root: BrowsingNode) {
        self.root = root
        self.current = root
    }

    // Codable:
    enum CodingKeys: String, CodingKey {
        case root
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        root = try container.decode(BrowsingNode.self, forKey: .root)
        current = root
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(root, forKey: .root)
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
        let node = BrowsingNode(parent: current, url: link, title: title)
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

    var sortedLinks: [(UInt64, Float)] {
        var scores = [(UInt64, Float)]()
        for link in links {
            let linkScore = AppDelegate.main.data.scores.scoreCard(for: link)
            scores.append((link, linkScore.score))
        }

        return scores.sorted { left, right -> Bool in
            left.1 < right.1
        }
    }
}
