//
//  BrowsingTreeProcessorTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 20/12/2021.
//
@testable import BeamCore
@testable import Beam

import XCTest

class BrowsingTreeProcessorTest: XCTestCase {

    override func setUpWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try BeamData.shared.urlHistoryManager?.clearUrlFrecencies()
        Persistence.cleanUp()
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try BeamData.shared.urlHistoryManager?.clearUrlFrecencies()
        Persistence.cleanUp()
        try BeamData.shared.urlStatsDBManager?.clearLongTermScores()
     }

    func testTreeProcess() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = LongTermUrlScoreStore()

        //processing an internal browsingTree
        let processor = BrowsingTreeProcessor()
        let tree = BrowsingTree(.searchBar(query: "hot to get a ps5 before christmas", referringRootId: nil))
        tree.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false)
        BeamDate.travel(2)
        tree.switchToBackground()
        var longTermScores = store.getMany(urlIds: [tree.current.link])
        XCTAssertEqual(longTermScores.count, 0)

        processor.process(tree: tree)

        //LongTerm Url Scores should be inserted
        longTermScores = store.getMany(urlIds: [tree.current.link])
        XCTAssertEqual(longTermScores.count, 1)
        BeamDate.reset()

        guard var frecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: tree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        var visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        var readingTimeFrecencyRecord = try XCTUnwrap(frecencies[.webReadingTime30d0])
        XCTAssertEqual(readingTimeFrecencyRecord.frecencyScore, 3)

        //domain url id frecencies should also be updated
        var domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: tree.current.link))
        guard var domainFrecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: domainId) else {
            throw BeamDataError.databaseNotFound
        }
        visitFrecencyRecord = try XCTUnwrap(domainFrecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 0.5)
        readingTimeFrecencyRecord = try XCTUnwrap(domainFrecencies[.webReadingTime30d0])
        XCTAssertEqual(readingTimeFrecencyRecord.frecencyScore, 1.0)

        //processing an imported browsingTree
        let importedTree = BrowsingTree(.historyImport(sourceBrowser: .chrome))
        importedTree.navigateTo(url: "http://www.whatever.com/ps6", title: "search", startReading: true, isLinkActivation: false)
        importedTree.switchToBackground()
        longTermScores = store.getMany(urlIds: [importedTree.current.link])
        XCTAssertEqual(longTermScores.count, 0)
        processor.process(tree: importedTree)
        longTermScores = store.getMany(urlIds: [importedTree.current.link])
        XCTAssertEqual(longTermScores.count, 0) //history imported from other browsers doesn't contain scores

        guard let _frecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: importedTree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        frecencies = _frecencies
        visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        XCTAssertNil(frecencies[.webReadingTime30d0])

        //domain url id frecencies should also be updated
        domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: importedTree.current.link))
        guard let _domainFrecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: domainId) else {
            throw BeamDataError.databaseNotFound
        }
        domainFrecencies = _domainFrecencies

        visitFrecencyRecord = try XCTUnwrap(domainFrecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 0.5)
        XCTAssertNil(domainFrecencies[.webReadingTime30d0])

        BeamDate.reset()
    }

    func testTreeProcessImportDate() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")

        //processing an internal browsingTree
        let processor = BrowsingTreeProcessor()
        let tree0 = BrowsingTree(.historyImport(sourceBrowser: .chrome))
        let tree1 = BrowsingTree(.historyImport(sourceBrowser: .chrome))

        tree0.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false)
        let link0 = tree0.current.link
        BeamDate.travel(2)
        tree1.navigateTo(url: "http://www.search.com/switch", title: "search", startReading: true, isLinkActivation: false)
        let t1 = BeamDate.now
        BeamDate.travel(2)
        tree0.navigateTo(url: "http://www.search.com/xbox", title: "search", startReading: true, isLinkActivation: false)
        let link2 = tree0.current.link
        let t2 = BeamDate.now

        //first tree import: a max import date is stored
        XCTAssertNil(Persistence.ImportedBrowserHistory.getMaxDate(for: .chrome))
        processor.process(tree: tree1)
        XCTAssertEqual(Persistence.ImportedBrowserHistory.getMaxDate(for: .chrome), t1)

        //second tree import: previously stored max import date filters newly imported nodes
        processor.process(tree: tree0)
        XCTAssertEqual(Persistence.ImportedBrowserHistory.getMaxDate(for: .chrome), t2)
        //node whose date is > t1
        XCTAssert(try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: link2).count ?? 0 > 0)
        //node whose date is < t1
        XCTAssertEqual(try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: link0).count, 0)

        BeamDate.reset()
    }

    func testLongTermScoreUpdate() throws {
        let grdbStore = GRDBStore.empty()
        let db = try UrlStatsDBManager(store: grdbStore)
        try grdbStore.migrate()

        let store = LongTermUrlScoreStore(db: db)
        let updater = LongTermScoreUpdater(scoreStore: store)

        let tree = BrowsingTree(nil)
        let id0 = tree.current.link
        let creationDate0 = try XCTUnwrap(tree.current.events.first?.date)
        tree.navigateTo(url: "https://fruit.org/orange", title: nil, startReading: false, isLinkActivation: true)
        let id1 = tree.current.link
        let creationDate1 = try XCTUnwrap(tree.current.events.first?.date)
        let treeScore0 = tree.scoreFor(link: id0)
        treeScore0.scrollRatioX = 0.2
        treeScore0.readingTimeToLastEvent = 100
        treeScore0.navigationCountSinceLastSearch = 2
        let treeScore1 = tree.scoreFor(link: id1)
        treeScore1.scrollRatioY = 0.5
        treeScore1.area = 1000

        let longTermScore0 = LongTermUrlScore(urlId: id0)
        longTermScore0.scrollRatioX = 0.5
        longTermScore0.readingTimeToLastEvent = 50
        longTermScore0.lastCreationDate = creationDate0 - Double(2)
        longTermScore0.navigationCountSinceLastSearch = 5
        store.save(scores: [longTermScore0])

        updater.update(using: tree)
        let updatedScores = store.getMany(urlIds: [id0, id1])
        XCTAssertEqual(updatedScores.count, 2)

        XCTAssertEqual(updatedScores[id0]?.visitCount, 1)
        XCTAssertEqual(updatedScores[id0]?.readingTimeToLastEvent, 150)
        XCTAssertEqual(updatedScores[id0]?.scrollRatioX, 0.5)
        XCTAssertEqual(updatedScores[id0]?.scrollRatioY, 0.0)
        XCTAssertEqual(updatedScores[id0]?.textAmount, 0)
        XCTAssertEqual(updatedScores[id0]?.textSelections, 0)
        XCTAssertEqual(updatedScores[id0]?.area, 0)
        XCTAssertEqual(updatedScores[id0]?.navigationCountSinceLastSearch, 2)
        let savedLastCreationDate0 = try XCTUnwrap(updatedScores[id0]?.lastCreationDate)
        XCTAssert(abs(savedLastCreationDate0.timeIntervalSince(creationDate0)) < 0.001)

        XCTAssertEqual(updatedScores[id1]?.visitCount, 1)
        XCTAssertEqual(updatedScores[id1]?.readingTimeToLastEvent, 0)
        XCTAssertEqual(updatedScores[id1]?.scrollRatioX, 0.0)
        XCTAssertEqual(updatedScores[id1]?.scrollRatioY, 0.5)
        XCTAssertEqual(updatedScores[id1]?.textAmount, 0)
        XCTAssertEqual(updatedScores[id1]?.textSelections, 0)
        XCTAssertEqual(updatedScores[id1]?.area, 1000)
        XCTAssertEqual(updatedScores[id1]?.navigationCountSinceLastSearch, 1)
        let savedLastCreationDate1 = try XCTUnwrap(updatedScores[id1]?.lastCreationDate)
        XCTAssert(abs(savedLastCreationDate1.timeIntervalSince(creationDate1)) < 0.001)
    }
}
