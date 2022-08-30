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
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        try BeamData.shared.urlHistoryManager?.clearUrlFrecencies()
        try BeamData.shared.browsingTreeDBManager?.clearBrowsingTrees()
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in}
        try BeamData.shared.urlHistoryManager?.clearUrlFrecencies()
        try BeamData.shared.browsingTreeDBManager?.clearBrowsingTrees()
    }

    func testTreeProcessTrigger() throws {
        let store = try XCTUnwrap(BrowsingTreeStoreManager(objectManager: BeamObjectManager()))

        let tree = BrowsingTree(nil)
        tree.navigateTo(url: "http://hello", title: nil, startReading: false, isLinkActivation: false)
        let record = try XCTUnwrap(tree.toRecord())

        let savedTree = BrowsingTree(nil)
        savedTree.navigateTo(url: "http://world", title: nil, startReading: false, isLinkActivation: false)
        let savedRecord = try XCTUnwrap(savedTree.toRecord())
        try BeamData.shared.browsingTreeDBManager?.save(browsingTreeRecord: savedRecord)

        let alreadyProcessingTree = BrowsingTree(nil)
        alreadyProcessingTree.navigateTo(url: "http://beam", title: nil, startReading: false, isLinkActivation: false)
        var alreadyProcessingRecord = try XCTUnwrap(alreadyProcessingTree.toRecord())
        alreadyProcessingRecord.processingStatus = .started
        try BeamData.shared.browsingTreeDBManager?.save(browsingTreeRecord: alreadyProcessingRecord)

        try store.receivedObjects([record, savedRecord, alreadyProcessingRecord])
        expect(store.treeProcessingCompleted).toEventually(beTrue())

        //received tree not already stored in db should trigger tree processsing
        guard let treeFrecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: tree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        XCTAssert(treeFrecencies.count > 0)

        //tree record already in db with done should not trigger processing when received
        guard let savedTreeFrecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: savedTree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        XCTAssertEqual(savedTreeFrecencies.count, 0)

        //tree record already in db with started status should not trigger processing when received
        guard let processingTreeFrecencies = try BeamData.shared.urlHistoryManager?.fetchOneFrecency(fromUrl: alreadyProcessingTree.current.link) else {
            throw BeamDataError.databaseNotFound
        }
        XCTAssertEqual(processingTreeFrecencies.count, 0)
    }

    func testSaveFetchLocal() throws {
        let store = try XCTUnwrap(BrowsingTreeStoreManager(objectManager: BeamObjectManager()))
        let tree = BrowsingTree(nil)
        let rootId = try XCTUnwrap(tree.rootId)
        try store.save(browsingTree: tree)
        let fetchedRecord = try XCTUnwrap(store.getBrowsingTree(rootId: rootId))
        XCTAssertNil(fetchedRecord.data)
        let flattened = try XCTUnwrap(fetchedRecord.flattenedData)
        XCTAssertEqual(tree.flattened, flattened)
    }

    func testRemoteFlattening() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = try XCTUnwrap(BrowsingTreeStoreManager(objectManager: BeamObjectManager()))
        let tree0 = BrowsingTree(nil)
        let rootId = try XCTUnwrap(tree0.rootId)
        let rootCreatedAt = try XCTUnwrap(tree0.root.events.first?.date)
        let recursiveRecord = BrowsingTreeRecord(rootId: rootId, rootCreatedAt: rootCreatedAt, appSessionId: nil, data: tree0, flattenedData: nil)

        let tree1 = BrowsingTree(nil)
        let flattenedRecord = try XCTUnwrap(tree1.toRecord())
        BeamDate.travel(1)
        try store.receivedObjects([recursiveRecord, flattenedRecord])

        //a downward synced former recursive tree should have it's updatedAt changed
        let savedRecursiveRecord = try XCTUnwrap(try store.getBrowsingTree(rootId: recursiveRecord.rootId))
        XCTAssertNil(savedRecursiveRecord.data)
        XCTAssertNotNil(savedRecursiveRecord.flattened)
        XCTAssert(savedRecursiveRecord.createdAt < savedRecursiveRecord.updatedAt)

        //a downward synced already flattened tree should have it's updatedAt untouched
        let savedFlattenedRecord = try XCTUnwrap(try store.getBrowsingTree(rootId: flattenedRecord.rootId))
        XCTAssertNil(savedFlattenedRecord.data)
        XCTAssertNotNil(savedFlattenedRecord.flattened)
        XCTAssertEqual(savedFlattenedRecord.createdAt, savedFlattenedRecord.updatedAt)
        BeamDate.reset()
    }

    func testSoftDelete() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = try XCTUnwrap(BrowsingTreeStoreManager(objectManager: BeamObjectManager()))

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
