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
     }

    func testTreeProcess() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")

        //processing an internal browsingTree
        let processor = BrowsingTreeProcessor()
        let tree = BrowsingTree(.searchBar(query: "hot to get a ps5 before christmas", referringRootId: nil))
        tree.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false, readCount: 0)
        BeamDate.travel(2)
        tree.switchToBackground()
        processor.process(tree: tree)

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
        processor.process(tree: importedTree)

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
}
