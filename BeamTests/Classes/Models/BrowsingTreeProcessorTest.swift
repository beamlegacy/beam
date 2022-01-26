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
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
    }

    override func tearDownWithError() throws {
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
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
}
