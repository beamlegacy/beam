//
//  BrowsingTreeStatsTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 04/03/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore
import GRDB

class BrowsingTreeStatsTest: XCTestCase {

    func testStats() throws {
        let db = GRDBDatabase.empty()
        BeamDate.freeze("2001-01-01T13:40:12+000")
        let treeIds = [UUID(), UUID()]
        try db.updateBrowsingTreeStats(treeId: treeIds[0]) { record in
            record.lifeTime = 5
        }
        try db.updateBrowsingTreeStats(treeId: treeIds[0]) { record in
            record.readingTime = 2
        }
        try db.updateBrowsingTreeStats(treeId: treeIds[1]) { record in
            record.lifeTime = 7
        }
        let firstRecord = try XCTUnwrap(db.getBrowsingTreeStats(treeId: treeIds[0]))
        XCTAssertEqual(firstRecord.lifeTime, 5.0)
        XCTAssertEqual(firstRecord.readingTime, 2.0)
        BeamDate.travel(24 * 60 * 60)
        try db.updateBrowsingTreeStats(treeId: treeIds[1]) { record in
            record.lifeTime = 10
        }
        // first record is updated at more than one day ago and gets cleaned
        try db.cleanBrowsingTreeStats(olderThan: 1)
        XCTAssertNil(try db.getBrowsingTreeStats(treeId: treeIds[0]))
        _ =  try XCTUnwrap(db.getBrowsingTreeStats(treeId: treeIds[1]))

        //test of rank based cleanup
        try db.updateBrowsingTreeStats(treeId: treeIds[0]) { record in
            record.lifeTime = 0
        }
        BeamDate.travel(1)

        try db.updateBrowsingTreeStats(treeId: treeIds[1]) { record in
            record.lifeTime = 0
        }
        try db.cleanBrowsingTreeStats(olderThan: 10*1000, maxRows: 1)
        XCTAssertNil(try db.getBrowsingTreeStats(treeId: treeIds[0]))
        _ =  try XCTUnwrap(db.getBrowsingTreeStats(treeId: treeIds[1]))
        BeamDate.reset()
    }
}
