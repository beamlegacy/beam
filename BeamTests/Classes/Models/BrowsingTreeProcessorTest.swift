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
        try GRDBDatabase.shared.clearUrlFrecencies()
        Persistence.cleanUp()
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try GRDBDatabase.shared.clearUrlFrecencies()
        Persistence.cleanUp()
        try GRDBDatabase.shared.clearLongTermScores()
     }

    func testTreeProcess() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = LongTermUrlScoreStore()

        //processing an internal browsingTree
        let processor = BrowsingTreeProcessor()
        let tree = BrowsingTree(.searchBar(query: "hot to get a ps5 before christmas", referringRootId: nil))
        tree.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
        BeamDate.travel(2)
        tree.switchToBackground()
        var longTermScores = store.getMany(urlIds: [tree.current.link])
        XCTAssertEqual(longTermScores.count, 0)

        processor.process(tree: tree)

        //LongTerm Url Scores should be inserted
        longTermScores = store.getMany(urlIds: [tree.current.link])
        XCTAssertEqual(longTermScores.count, 1)
        BeamDate.reset()

        var frecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: tree.current.link)
        var visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        var readingTimeFrecencyRecord = try XCTUnwrap(frecencies[.webReadingTime30d0])
        XCTAssertEqual(readingTimeFrecencyRecord.frecencyScore, 3)

        //domain url id frecencies should also be updated
        var domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: tree.current.link))
        var domainFrecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: domainId)
        visitFrecencyRecord = try XCTUnwrap(domainFrecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 0.5)
        readingTimeFrecencyRecord = try XCTUnwrap(domainFrecencies[.webReadingTime30d0])
        XCTAssertEqual(readingTimeFrecencyRecord.frecencyScore, 1.0)

        //processing an imported browsingTree
        let importedTree = BrowsingTree(.historyImport(sourceBrowser: .chrome))
        importedTree.navigateTo(url: "http://www.whatever.com/ps6", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
        importedTree.switchToBackground()
        longTermScores = store.getMany(urlIds: [importedTree.current.link])
        XCTAssertEqual(longTermScores.count, 0)
        processor.process(tree: importedTree)
        longTermScores = store.getMany(urlIds: [importedTree.current.link])
        XCTAssertEqual(longTermScores.count, 0) //history imported from other browsers doesn't contain scores

        frecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: importedTree.current.link)
        visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        XCTAssertNil(frecencies[.webReadingTime30d0])

        //domain url id frecencies should also be updated
        domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: importedTree.current.link))
        domainFrecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: domainId)
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

        tree0.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
        let link0 = tree0.current.link
        BeamDate.travel(2)
        tree1.navigateTo(url: "http://www.search.com/switch", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
        let t1 = BeamDate.now
        BeamDate.travel(2)
        tree0.navigateTo(url: "http://www.search.com/xbox", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
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
        XCTAssert(try GRDBDatabase.shared.fetchOneFrecency(fromUrl: link2).count > 0)
        //node whose date is < t1
        XCTAssertEqual(try GRDBDatabase.shared.fetchOneFrecency(fromUrl: link0).count, 0)

        BeamDate.reset()
    }

    func testLongTermScoreUpdate() throws {
        let store = LongTermUrlScoreStore(db: GRDBDatabase.empty())
        let updater = LongTermScoreUpdater(scoreStore: store)

        let tree = BrowsingTree(nil)
        let id0 = tree.current.link
        let creationDate0 = try XCTUnwrap(tree.current.events.first?.date)
        tree.navigateTo(url: "https://fruit.org/orange", title: nil, startReading: false, isLinkActivation: false, readCount: 0)
        let id1 = tree.current.link
        let creationDate1 = try XCTUnwrap(tree.current.events.first?.date)
        let treeScore0 = tree.scoreFor(link: id0)
        treeScore0.scrollRatioX = 0.2
        treeScore0.readingTimeToLastEvent = 100
        let treeScore1 = tree.scoreFor(link: id1)
        treeScore1.scrollRatioY = 0.5
        treeScore1.area = 1000

        let longTermScore0 = LongTermUrlScore(urlId: id0)
        longTermScore0.scrollRatioX = 0.5
        longTermScore0.readingTimeToLastEvent = 50
        longTermScore0.lastCreationDate = creationDate0 - Double(2)
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
        let savedLastCreationDate0 = try XCTUnwrap(updatedScores[id0]?.lastCreationDate)
        XCTAssert(abs(savedLastCreationDate0.timeIntervalSince(creationDate0)) < 0.001)

        XCTAssertEqual(updatedScores[id1]?.visitCount, 1)
        XCTAssertEqual(updatedScores[id1]?.readingTimeToLastEvent, 0)
        XCTAssertEqual(updatedScores[id1]?.scrollRatioX, 0.0)
        XCTAssertEqual(updatedScores[id1]?.scrollRatioY, 0.5)
        XCTAssertEqual(updatedScores[id1]?.textAmount, 0)
        XCTAssertEqual(updatedScores[id1]?.textSelections, 0)
        XCTAssertEqual(updatedScores[id1]?.area, 1000)
        let savedLastCreationDate1 = try XCTUnwrap(updatedScores[id1]?.lastCreationDate)
        XCTAssert(abs(savedLastCreationDate1.timeIntervalSince(creationDate1)) < 0.001)
    }
}
