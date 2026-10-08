//
//  BrowsingTreeStoreTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 21/12/2021.
//

import XCTest
import Nimble
@testable import BeamCore
@testable import Beam

class BrowsingTreeStoreTest: XCTestCase {

    override func setUpWithError() throws {
        LinkStore.shared.deleteAll()
        try BeamData.shared.linksDBManager?.clearUrlFrecencies()
        try BeamData.shared.browsingTreeDBManager?.clearBrowsingTrees()
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll()
        try BeamData.shared.linksDBManager?.clearUrlFrecencies()
        try BeamData.shared.browsingTreeDBManager?.clearBrowsingTrees()
    }

    func testSaveFetchLocal() throws {
        let store = try XCTUnwrap(BrowsingTreeStoreManager())
        let tree = BrowsingTree(nil)
        let rootId = try XCTUnwrap(tree.rootId)
        try store.save(browsingTree: tree)
        let fetchedRecord = try XCTUnwrap(store.getBrowsingTree(rootId: rootId))
        XCTAssertNil(fetchedRecord.data)
        let flattened = try XCTUnwrap(fetchedRecord.flattenedData)
        XCTAssertEqual(tree.flattened, flattened)
    }

    func testSoftDelete() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = try XCTUnwrap(BrowsingTreeStoreManager())

        //absolute date based soft deletion
        let tree0 = BrowsingTree(nil)
        try store.save(browsingTree: tree0, appSessionId: nil)
        BeamDate.travel(3 * 24 * 60 * 60)
        let tree1 = BrowsingTree(nil)
        try store.save(browsingTree: tree1, appSessionId: nil)
        store.softDelete(olderThan: 1, maxRows: 10)
        //tree older than 1 day is deleted
        let fetchedTree0 = try XCTUnwrap(try store.getBrowsingTree(rootId: tree0.root.id))
        XCTAssertEqual(fetchedTree0.updatedAt, BeamDate.now)
        XCTAssertEqual(fetchedTree0.deletedAt, BeamDate.now)
        XCTAssertNil(fetchedTree0.flattenedData)
        //today's tree is untouched
        var fetchedTree1 = try XCTUnwrap(try store.getBrowsingTree(rootId: tree1.root.id))
        XCTAssertNil(fetchedTree1.deletedAt)

        //rank based soft deletion
        BeamDate.travel(1 * 24 * 60 * 60)
        let tree2 = BrowsingTree(nil)
        try store.save(browsingTree: tree2, appSessionId: nil)
        store.softDelete(olderThan: 1000, maxRows: 1)
        //2nd most recent tree is soft deleted
        fetchedTree1 = try XCTUnwrap(try store.getBrowsingTree(rootId: tree0.root.id))
        XCTAssertEqual(fetchedTree1.updatedAt, BeamDate.now)
        XCTAssertEqual(fetchedTree1.deletedAt, BeamDate.now)
        XCTAssertNil(fetchedTree1.flattenedData)
        //most recent tree is untouched
        let fetchedTree2 = try XCTUnwrap(try store.getBrowsingTree(rootId: tree2.root.id))
        XCTAssertNil(fetchedTree2.deletedAt)
    }
}
