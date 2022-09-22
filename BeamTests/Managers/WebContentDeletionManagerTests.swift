//
//  WebContentDeletionManagerTests.swift
//  BeamTests
//
//  Created by Remi Santos on 19/09/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class WebContentDeletionManagerTests: XCTestCase {

    private var data: BeamData!
    override func setUp() {
        data = BeamData()
    }

    override func tearDown() {
        BeamDate.reset()
    }

    private let travel1Minute: TimeInterval = 60
    private let travel1Hour: TimeInterval = 60 * 60
    private var travel1Day: TimeInterval { 24 * travel1Hour }
    private var travel1Month: TimeInterval { 31 * travel1Day }

    private func resetDate() {
        BeamDate.freeze("2020-03-01T00:00:00+000")
    }

    private var trees: [BrowsingTree] = []
    private var domainPaths: [String] = [
        "minute.beamapp.co",
        "hour.beamapp.co",
        "day.beamapp.co",
        "month.beamapp.co"]
    private var localDayString: String {
        BeamDate.now.localDayString() ?? ""
    }
    private func setUpHistory() throws {
        resetDate()

        let browsingTreeStore = try XCTUnwrap(BrowsingTreeStoreManager(objectManager: BeamObjectManager()))
        let tabPinSuggestions = data.tabPinSuggestionDBManager

        // 1 minute old
        BeamDate.travel(-travel1Minute)
        let tree0 = BrowsingTree(nil)
        try browsingTreeStore.save(browsingTree: tree0, appSessionId: nil)
        try tabPinSuggestions?.addTabPinSuggestion(domainPath0: domainPaths[0])
        try tabPinSuggestions?.addDomainPath0ReadingDay(domainPath0: domainPaths[0], date: BeamDate.now)
        try tabPinSuggestions?.updateDomainPath0TreeStat(domainPath0: domainPaths[0], treeId: tree0.root.id, readingTime: 1)
        let link0 = Link(url: domainPaths[0], title: nil, content: nil)
        try data.linksDBManager?.insert(links: [link0])
        data.urlStatsDBManager?.updateDailyUrlScore(urlId: link0.id, day: localDayString) { _ in }
        try data.mnemonicManager?.insertMnemonic(text: "0", url: link0.id)

        // 1 hour old
        BeamDate.travel(-travel1Hour)
        let tree1 = BrowsingTree(nil)
        try browsingTreeStore.save(browsingTree: tree1, appSessionId: nil)
        try tabPinSuggestions?.addTabPinSuggestion(domainPath0: domainPaths[1])
        try tabPinSuggestions?.addDomainPath0ReadingDay(domainPath0: domainPaths[1], date: BeamDate.now)
        try tabPinSuggestions?.updateDomainPath0TreeStat(domainPath0: domainPaths[1], treeId: tree1.root.id, readingTime: 1)
        let link1 = Link(url: domainPaths[1], title: nil, content: nil)
        try data.linksDBManager?.insert(links: [link1])
        data.urlStatsDBManager?.updateDailyUrlScore(urlId: link1.id, day: localDayString) { _ in }
        try data.mnemonicManager?.insertMnemonic(text: "1", url: link1.id)

        // 1 day old
        BeamDate.travel(-travel1Day)
        let tree2 = BrowsingTree(nil)
        try browsingTreeStore.save(browsingTree: tree2, appSessionId: nil)
        try tabPinSuggestions?.addTabPinSuggestion(domainPath0: domainPaths[2])
        try tabPinSuggestions?.addDomainPath0ReadingDay(domainPath0: domainPaths[2], date: BeamDate.now)
        try tabPinSuggestions?.updateDomainPath0TreeStat(domainPath0: domainPaths[2], treeId: tree2.root.id, readingTime: 1)
        let link2 = Link(url: domainPaths[2], title: nil, content: nil)
        try data.linksDBManager?.insert(links: [link2])
        data.urlStatsDBManager?.updateDailyUrlScore(urlId: link2.id, day: localDayString) { _ in }
        try data.mnemonicManager?.insertMnemonic(text: "2", url: link2.id)

        // 1 month old
        BeamDate.travel(-travel1Month)
        let tree3 = BrowsingTree(nil)
        try browsingTreeStore.save(browsingTree: tree3, appSessionId: nil)
        try tabPinSuggestions?.addTabPinSuggestion(domainPath0: domainPaths[3])
        try tabPinSuggestions?.addDomainPath0ReadingDay(domainPath0: domainPaths[3], date: BeamDate.now)
        try tabPinSuggestions?.updateDomainPath0TreeStat(domainPath0: domainPaths[3], treeId: tree3.root.id, readingTime: 1)
        let link3 = Link(url: domainPaths[3], title: nil, content: nil)
        try data.linksDBManager?.insert(links: [link3])
        data.urlStatsDBManager?.updateDailyUrlScore(urlId: link3.id, day: localDayString) { _ in }
        try data.mnemonicManager?.insertMnemonic(text: "3", url: link3.id)

        resetDate()
        trees = [tree0, tree1, tree2, tree3]
    }

    func testClearHistory() throws {
        try setUpHistory()
        let sut = WebContentDeletionManager(accountData: data)

        // initial state
        XCTAssertEqual(try data.linksDBManager?.allLinks(updatedSince: nil).count, 4)
        XCTAssertNotNil(data.mnemonicManager?.getMnemonic(text: "0"))
        XCTAssertEqual(data.browsingTreeDBManager?.countBrowsingTrees, 4)
        XCTAssertEqual(data.tabPinSuggestionDBManager?.tabPinSuggestionCount, 4)
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[0]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[0], treeId: trees[0].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[1]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[1], treeId: trees[1].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[2]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[2], treeId: trees[2].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[3]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[3], treeId: trees[3].root.id))

        // clear 1 hour old
        try sut.clearHistory(.hour)
        XCTAssertEqual(try data.linksDBManager?.allLinks(updatedSince: nil).count, 3)
        XCTAssertNil(data.mnemonicManager?.getMnemonic(text: "0"))
        XCTAssertNotNil(data.mnemonicManager?.getMnemonic(text: "1"))
        XCTAssertEqual(data.browsingTreeDBManager?.countBrowsingTrees, 3)
        XCTAssertEqual(data.tabPinSuggestionDBManager?.tabPinSuggestionCount, 3)
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[0]), 0)
        XCTAssertNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[0], treeId: trees[0].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[1]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[1], treeId: trees[1].root.id))

        // clear 1 day old
        try sut.clearHistory(.day)
        XCTAssertEqual(try data.linksDBManager?.allLinks(updatedSince: nil).count, 2)
        XCTAssertNil(data.mnemonicManager?.getMnemonic(text: "1"))
        XCTAssertNotNil(data.mnemonicManager?.getMnemonic(text: "2"))
        XCTAssertEqual(data.browsingTreeDBManager?.countBrowsingTrees, 2)
        XCTAssertEqual(data.tabPinSuggestionDBManager?.tabPinSuggestionCount, 2)
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[1]), 0)
        XCTAssertNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[1], treeId: trees[1].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[2]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[2], treeId: trees[2].root.id))


        // clear 1 month old
        try sut.clearHistory(.month)
        XCTAssertEqual(try data.linksDBManager?.allLinks(updatedSince: nil).count, 1)
        XCTAssertNil(data.mnemonicManager?.getMnemonic(text: "2"))
        XCTAssertNotNil(data.mnemonicManager?.getMnemonic(text: "3"))
        XCTAssertEqual(data.browsingTreeDBManager?.countBrowsingTrees, 1)
        XCTAssertEqual(data.tabPinSuggestionDBManager?.tabPinSuggestionCount, 1)
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[2]), 0)
        XCTAssertNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[2], treeId: trees[2].root.id))
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[3]), 1)
        XCTAssertNotNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[3], treeId: trees[3].root.id))

        // clear all
        try sut.clearHistory(.all)
        XCTAssertEqual(try data.linksDBManager?.allLinks(updatedSince: nil).count, 0)
        XCTAssertNil(data.mnemonicManager?.getMnemonic(text: "3"))
        XCTAssertEqual(data.browsingTreeDBManager?.countBrowsingTrees, 0)
        XCTAssertEqual(data.tabPinSuggestionDBManager?.tabPinSuggestionCount, 0)
        XCTAssertEqual(try data.tabPinSuggestionDBManager?.countDomainPath0ReadingDay(domainPath0: domainPaths[3]), 0)
        XCTAssertNil(try data.tabPinSuggestionDBManager?.getDomainPath0TreeStat(domainPath0: domainPaths[3], treeId: trees[3].root.id))
    }

}
