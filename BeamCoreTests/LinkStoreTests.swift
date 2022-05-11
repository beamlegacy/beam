//
//  LinkStoreTests.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 11/05/2022.
//

import XCTest
@testable import BeamCore

class LinkStoreTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMissingLinkHandling() {
        let linkManager = InMemoryLinkManager()
        let linkStore = LinkStore(linkManager: linkManager)
        //when getting id for missing url, it retreives the link but doesn't save it in db
        let createdLinkId: UUID = linkStore.getOrCreateId(for: "<???>", title: nil, content: nil, destination: nil)
        XCTAssertEqual(createdLinkId, Link.missing.id)
        XCTAssertNil(linkManager.linkFor(id: Link.missing.id))

        //when visiting missing url, it retreives the link but doesn't save it in db
        let visitedLinkId: UUID = linkStore.visit("<???>", title: nil, content: nil, destination: nil).id
        XCTAssertEqual(visitedLinkId, Link.missing.id)
        XCTAssertNil(linkManager.linkFor(id: Link.missing.id))
    }

    func testUrlNormalization() {
        let linkManager = InMemoryLinkManager()
        let linkStore = LinkStore(linkManager: linkManager)
        let nonStandardUrl = "http://lemonde.fr"
        let standardUrl = "http://lemonde.fr/"
        let id0 = linkStore.getOrCreateId(for: nonStandardUrl, title: nil, content: nil, destination: nil)
        let id1 = linkStore.getOrCreateId(for: standardUrl, title: nil, content: nil, destination: nil)
        XCTAssertEqual(id0, id1)

        let link0 = linkStore.visit(nonStandardUrl, title: nil, content: nil, destination: nil)
        let link1 = linkStore.visit(standardUrl, title: nil, content: nil, destination: nil)
        XCTAssertEqual(link0.id, id0)
        XCTAssertEqual(link1.id, id0)
        XCTAssertEqual(link0.url, standardUrl)
        XCTAssertEqual(link1.url, standardUrl)
    }

    func testTitlePreprocessing() throws {
        let linkManager = InMemoryLinkManager()
        let linkStore = LinkStore(linkManager: linkManager)
        let id0 = linkStore.getOrCreateId(for: "http://site.com/", title: "\tTitle ", content: nil, destination: nil)
        let link0 = try XCTUnwrap(linkStore.linkFor(id: id0))
        XCTAssertEqual(link0.title, "Title")

        let id1 = linkStore.visit("http://site.com/", title: "\tTitle ", content: nil, destination: nil).id
        let link1 = try XCTUnwrap(linkStore.linkFor(id: id1))
        XCTAssertEqual(link1.title, "Title")
    }
}
