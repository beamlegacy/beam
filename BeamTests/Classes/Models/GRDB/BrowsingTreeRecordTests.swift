//
//  BrowsingTreeRecordTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 08/10/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class BrowsingTreeRecordTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    func testRecord() throws {
        let db = GRDBDatabase.empty()
        let appSessionId = UUID()
        let tree = BrowsingTree(nil)
        let rootId = tree.root.id

        //test save/get of one tree
        let record = try XCTUnwrap(tree.toRecord(appSessionId: appSessionId))
        try XCTAssert(!db.exists(browsingTreeRecord: record))
        XCTAssertEqual(db.countBrowsingTrees, 0)
        try db.save(browsingTreeRecord: record)
        XCTAssertEqual(db.countBrowsingTrees, 1)
        XCTAssert(try db.exists(browsingTreeRecord: record))
        try db.save(browsingTreeRecord: record)

        //test saveMany/getMany trees
        let anotherTree = BrowsingTree(nil)
        let anotherRootId = anotherTree.root.id
        let anotherRecord = try XCTUnwrap(anotherTree.toRecord(appSessionId: appSessionId))
        try db.save(browsingTreeRecords: [record, anotherRecord])
        XCTAssertEqual(db.countBrowsingTrees, 2)
        var fetchedRecords = try XCTUnwrap(try? db.getBrowsingTrees(rootIds: [rootId, UUID()]))
        XCTAssertEqual(fetchedRecords.count, 1)
        XCTAssertEqual(fetchedRecords[0].rootId, rootId)

        //test getAll
        fetchedRecords = try XCTUnwrap(try? db.getAllBrowsingTrees())
        let sortedRecords = fetchedRecords.sorted {(left, right) in left.createdAt < right.createdAt }
        XCTAssertEqual(sortedRecords.count, 2)
        XCTAssertEqual(fetchedRecords[0].rootId, rootId)
        XCTAssertEqual(fetchedRecords[1].rootId, anotherRootId)

        fetchedRecords = try XCTUnwrap(try? db.getAllBrowsingTrees(updatedSince: sortedRecords[1].updatedAt))
        XCTAssertEqual(sortedRecords.count, 2)
        XCTAssertEqual(fetchedRecords[0].rootId, anotherRootId)

        //test delete
        XCTAssertEqual(db.countBrowsingTrees, 2)
        try db.deleteBrowsingTrees(ids: [rootId, anotherRootId])
        XCTAssertEqual(db.countBrowsingTrees, 0)
    }
}
