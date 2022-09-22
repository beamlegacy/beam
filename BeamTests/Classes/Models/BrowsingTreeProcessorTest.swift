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
        try BeamData.shared.linksDBManager?.clearUrlFrecencies()
        Persistence.cleanUp()
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try BeamData.shared.linksDBManager?.clearUrlFrecencies()
        Persistence.cleanUp()
     }

    func testTreeProcess() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")

        //processing an internal browsingTree
        let processor = BrowsingTreeProcessor()
        let tree = BrowsingTree(.searchBar(query: "hot to get a ps5 before christmas", referringRootId: nil))
        tree.navigateTo(url: "http://www.search.com/ps5", title: "search", startReading: true, isLinkActivation: false)
        BeamDate.travel(2)
        tree.switchToBackground()
        processor.process(tree: tree)
        BeamDate.reset()

        guard var frecencies = try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: tree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        var visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        var readingTimeFrecencyRecord = try XCTUnwrap(frecencies[.webReadingTime30d0])
        XCTAssertEqual(readingTimeFrecencyRecord.frecencyScore, 3)

        //domain url id frecencies should also be updated
        var domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: tree.current.link))
        guard var domainFrecencies = try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: domainId) else {
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
        processor.process(tree: importedTree)

        guard let _frecencies = try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: importedTree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        frecencies = _frecencies
        visitFrecencyRecord = try XCTUnwrap(frecencies[.webVisit30d0])
        XCTAssertEqual(visitFrecencyRecord.frecencyScore, 1.5)
        XCTAssertNil(frecencies[.webReadingTime30d0])

        //domain url id frecencies should also be updated
        domainId = try XCTUnwrap(LinkStore.shared.getDomainId(id: importedTree.current.link))
        guard let _domainFrecencies = try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: domainId) else {
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
        XCTAssert(try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: link2).count ?? 0 > 0)
        //node whose date is < t1
        XCTAssertEqual(try BeamData.shared.linksDBManager?.fetchOneFrecency(fromUrl: link0).count, 0)

        BeamDate.reset()
    }
}
