//
//  BrowsingTreeStoreTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 21/12/2021.
//

import XCTest
@testable import BeamCore
@testable import Beam

class BrowsingTreeStoreTest: XCTestCase {

    override func setUpWithError() throws {
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
        try GRDBDatabase.shared.clearBrowsingTrees()
    }

    override func tearDownWithError() throws {
        try LinkStore.shared.deleteAll()
        try GRDBDatabase.shared.clearUrlFrecencies()
        try GRDBDatabase.shared.clearBrowsingTrees()
    }

    func testReceivedOjects() throws {
        let store = BrowsingTreeStoreManager()
        let tree = BrowsingTree(nil)
        tree.navigateTo(url: "http://hello", title: nil, startReading: false, isLinkActivation: false, readCount: 0)
        let record = try XCTUnwrap(tree.toRecord())
        let savedTree = BrowsingTree(nil)
        savedTree.navigateTo(url: "http://world", title: nil, startReading: false, isLinkActivation: false, readCount: 0)
        let savedRecord = try XCTUnwrap(savedTree.toRecord())
        try GRDBDatabase.shared.save(browsingTreeRecord: savedRecord)

        try store.receivedObjects([record, savedRecord])

        //received tree not already stored in db should trigger tree processsing
        let treeFrecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: tree.current.link)
        XCTAssert(treeFrecencies.count > 0)

        //tree record already in db should not trigger processing when received
        let savedTreeFrecencies = try GRDBDatabase.shared.fetchOneFrecency(fromUrl: savedTree.current.link)
        XCTAssertEqual(savedTreeFrecencies.count, 0)

    }
}
