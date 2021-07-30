//
//  LongTermUrlScoreStoreTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import XCTest

@testable import Beam
@testable import BeamCore

class LongTermUrlScoreStoreTests: XCTestCase {

    func testDbRecord() throws {
        func assertZeroValues(score: LongTermUrlScore) {
            XCTAssertEqual(score.visitCount, 0)
            XCTAssertEqual(score.scrollRatioX, 0)
            XCTAssertEqual(score.scrollRatioY, 0)
            XCTAssertEqual(score.readingTimeToLastEvent, 0)
            XCTAssertEqual(score.textAmount, 0)
            XCTAssertEqual(score.area, 0)
        }
        
        func assertCount(urlId: UInt64, count: Int) throws {
            try db.dbReader.read { db in
                let query = LongTermUrlScore.filter(id: urlId)
                try XCTAssertEqual(query.fetchCount(db), count)
            }
        }

        let db = GRDBDatabase.empty()
        
        //when a given urlId's record does not exist yet, a 0 valued record (+ changes) is inserted
        let urlId: UInt64 = 0
        try assertCount(urlId: urlId, count: 0)
        db.updateLongTermUrlScore(urlId: urlId) { $0.textSelections += 1 }
        var score = try XCTUnwrap(db.getLongTermUrlScore(urlId: urlId))
        XCTAssertEqual(score.textSelections, 1)
        XCTAssertNil(score.lastCreationDate)
        assertZeroValues(score: score)
        try assertCount(urlId: urlId, count: 1)

        //when the urlId's record already exists, it's updated
        let date = Date()
        db.updateLongTermUrlScore(urlId: urlId) { $0.lastCreationDate = date }
        score = try XCTUnwrap(db.getLongTermUrlScore(urlId: urlId))
        XCTAssertEqual(score.textSelections, 1)
        let fetchedDate = try XCTUnwrap(score.lastCreationDate)
        XCTAssertEqual(fetchedDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1.0/1000.0)
        assertZeroValues(score: score)
        try assertCount(urlId: urlId, count: 1)
        
        //an other url id update doesnt interfere with previous one
        let otherUrlId: UInt64 = 1
        let otherDate =  Date()
        db.updateLongTermUrlScore(urlId: otherUrlId) { $0.lastCreationDate = otherDate }
        score = try XCTUnwrap(db.getLongTermUrlScore(urlId: urlId))
        XCTAssertEqual(fetchedDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1.0/1000.0)
    }
    
    func testGetMany() {
        let db = GRDBDatabase.empty()
        //fetching works for an empty list
        XCTAssertEqual(db.getManyLongTermUrlScore(urlIds: []).count, 0)
        
        let idsToInsert: [UInt64] = [0, 1, 3]
        let idsToFetch: [UInt64] = [1, 3, 7]
        //no score are fetched prior insertion
        XCTAssertEqual(db.getManyLongTermUrlScore(urlIds: idsToFetch).count, 0)
        for id in idsToInsert {
            db.updateLongTermUrlScore(urlId: id) { $0.lastCreationDate = Date() }
        }
        //2 of requested score ids were inserted prior fetch
        let fetchedScores = db.getManyLongTermUrlScore(urlIds: idsToFetch)
        XCTAssertEqual(fetchedScores.count, 2)
    }
}
