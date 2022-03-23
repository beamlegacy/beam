//
//  DomainPath0Tests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 04/03/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class DomainPath0Test: XCTestCase {

    func testReadingDay() throws {
        let db = GRDBDatabase.empty()
        BeamDate.freeze("2001-01-01T13:40:12+000")
        let firstDate = BeamDate.now
        let domainPath0s = ["abc.com/cat", "def.com/dog"]
        try db.addDomainPath0ReadingDay(domainPath0: domainPath0s[0], date: BeamDate.now)
        try db.addDomainPath0ReadingDay(domainPath0: domainPath0s[1], date: BeamDate.now)
        BeamDate.travel(1)
        //adding a readingDay on same day has no effect
        try db.addDomainPath0ReadingDay(domainPath0: domainPath0s[0], date: BeamDate.now)
        BeamDate.travel(24 * 60 * 60)
        try db.addDomainPath0ReadingDay(domainPath0: domainPath0s[0], date: BeamDate.now)
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: domainPath0s[0]), 2)
        XCTAssertEqual(db.domainPath0MinReadDay, firstDate.dayTruncated)
        try db.cleanDomainPath0ReadingDay(olderThan: 1) //in days
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: domainPath0s[0]), 1)

        //test of rank based cleanup
        BeamDate.travel(24 * 60 * 60)
        try db.addDomainPath0ReadingDay(domainPath0: domainPath0s[0], date: BeamDate.now)
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: domainPath0s[0]), 2)
        try db.cleanDomainPath0ReadingDay(olderThan: 10*1000, maxRows: 1)
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: domainPath0s[0]), 1)
        BeamDate.reset()
    }

    func testStats() throws {
        let db = GRDBDatabase.empty()
        BeamDate.freeze("2001-01-01T13:40:12+000")
        let domainPath0s = ["abc.com/cat", "def.com/dog"]
        let treeId = UUID()
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId, readingTime: 15.0)
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[1], treeId: treeId, readingTime: 10.0)
        var firstRecord = try XCTUnwrap(db.getDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId))
        XCTAssertEqual(firstRecord.readingTime, 15.0)
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId, readingTime: 5.0)
        firstRecord = try XCTUnwrap(db.getDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId))
        XCTAssertEqual(firstRecord.readingTime, 20.0)

        BeamDate.travel(24 * 60 * 60)
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[1], treeId: treeId, readingTime: 2.0)
        // first record is updated at more than one day ago and gets cleaned
        try db.cleanDomainPath0TreeStat(olderThan: 1)
        XCTAssertNil(try db.getDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId))
        _ =  try XCTUnwrap(db.getDomainPath0TreeStat(domainPath0: domainPath0s[1], treeId: treeId))
        
        //test of rank based cleanup
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId, readingTime: 12.0)
        BeamDate.travel(1)
        try db.updateDomainPath0TreeStat(domainPath0: domainPath0s[1], treeId: treeId, readingTime: 23.0)

        try db.cleanDomainPath0TreeStat(olderThan: 10*1000, maxRows: 1)
        XCTAssertNil(try db.getDomainPath0TreeStat(domainPath0: domainPath0s[0], treeId: treeId))
        _ =  try XCTUnwrap(try db.getDomainPath0TreeStat(domainPath0: domainPath0s[1], treeId: treeId))
        BeamDate.reset()
    }
    
    func testStorage() throws {
        let db = GRDBDatabase.empty()
        let storage = DomainPath0TreeStatsStorage(db: db)
        let treeId = UUID()
        BeamDate.freeze("2001-01-01T13:40:12+000")
        storage.update(treeId: treeId, url: "http://bird.s/on/a/branch" ,readTime: 1,  date: BeamDate.now)
        storage.update(treeId: treeId, url: "http://bird.s/on/a/branch" ,readTime: 1,  date: BeamDate.now)
        storage.update(treeId: treeId, lifeTime: 3)
        
        let domainTreeRecord = try XCTUnwrap(db.getDomainPath0TreeStat(domainPath0:  "http://bird.s/on", treeId: treeId))
        let domainRecord = try XCTUnwrap(db.getBrowsingTreeStats(treeId: treeId))
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: "http://bird.s/on"), 1)
        XCTAssertEqual(domainTreeRecord.readingTime, 2)
        XCTAssertEqual(domainRecord.readingTime, 2)
        XCTAssertEqual(domainRecord.lifeTime, 3)

        //to recent to be deleted
        storage.cleanUp(olderThan: 1, maxRows: 1000)
        _ = try XCTUnwrap(db.getDomainPath0TreeStat(domainPath0:  "http://bird.s/on", treeId: treeId))
        _ = try XCTUnwrap(db.getBrowsingTreeStats(treeId: treeId))
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: "http://bird.s/on"), 1)

        //old enough to be deleted
        BeamDate.travel(24 * 60 * 60 + 1)
        storage.cleanUp(olderThan: 1, maxRows: 1000)
        XCTAssertNil(try db.getDomainPath0TreeStat(domainPath0:  "http://bird.s/on", treeId: treeId))
        XCTAssertNil(try db.getBrowsingTreeStats(treeId: treeId))
        XCTAssertEqual(try db.countDomainPath0ReadingDay(domainPath0: "http://bird.s/on"), 0)
        BeamDate.reset()
    }
}
