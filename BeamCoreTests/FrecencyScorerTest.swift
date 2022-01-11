//
//  FrecencyScorerTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 18/06/2021.
//

import XCTest

@testable import BeamCore

typealias Table = [UUID: FrecencyScore]
typealias ScoreData = [FrecencyParamKey: Table]

class FrecencyScorerTest: XCTestCase {
    class FakeFrecencyStorage: FrecencyStorage {
        var data: ScoreData = ScoreData()

        func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
            return data[paramKey]?[id]
        }
        func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
            let urlId = score.id
            if data[paramKey] != nil {
                data[paramKey]?[urlId] = score
            } else {
                data[paramKey] = [urlId: score]
            }
        }
        func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws {
            for score in scores { try save(score: score, paramKey: paramKey) }
        }
    }

    var fakeStorage = FakeFrecencyStorage()

    override func setUp() {
        fakeStorage = FakeFrecencyStorage()
    }

    typealias StorageKey = (urlId: UUID, frecencyParam: FrecencyParamKey)
    private func expectFrecencyScoreInStorage(_ key: StorageKey,
                                              value: Float,
                                              lastTimestamp: Date,
                                              halfLife: Float,
                                              file: StaticString = #file,
                                              line: UInt = #line) throws {
        let score = try self.fakeStorage.fetchOne(id: key.urlId, paramKey: key.frecencyParam)
        XCTAssertEqual(score?.lastScore, value,
                       file: file, line: line)
        XCTAssertEqual(score?.lastTimestamp, lastTimestamp,
                       file: file, line: line)
        if value != 0 {
            XCTAssertEqual(score?.sortValue,
                           log(value) + Float(lastTimestamp.timeIntervalSinceReferenceDate) * log(2) / halfLife,
                           file: file, line: line)
        } else {
            XCTAssertEqual(score?.sortValue, -Float.greatestFiniteMagnitude)
        }

    }
    func testScoreObject() {
        let id = UUID()
        let now = BeamDate.now
        let halfLife: Float = 10
        let after = now + Double(halfLife)
        let before = now - Double(halfLife)
        let score = FrecencyScore(id: id, lastTimestamp: now, lastScore: 2, halfLife: halfLife)
        //updated with a future event
        let updatedFuture = score.updated(date: after, value: 5, halfLife: halfLife)
        XCTAssertEqual(updatedFuture.lastTimestamp, after)
        XCTAssertEqual(updatedFuture.lastScore, 2 / 2 + 5)
        //updated with a past event
        let updatedPast = score.updated(date: before, value: 6, halfLife: halfLife)
        XCTAssertEqual(updatedPast.lastTimestamp, now)
        XCTAssertEqual(updatedPast.lastScore, 2 + 6 / 2)
    }

    /// Test frecency score computation and insertion.
    func testScorer() throws {
        let halfLife = Float(10.0)

        let frecencyParameters: [FrecencyParamKey: FrecencyParam] = [
            .webReadingTime30d0: FrecencyParam(key: .webReadingTime30d0, eventWeights: [.webSearchBar: 2.0], halfLife: halfLife),
            .webVisit30d0: FrecencyParam(key: .webVisit30d0, eventWeights: [.webSearchBar: 2.0], halfLife: halfLife)
        ]
        let urlIds = (0...2).map { _ in UUID() }
        let scorer = ExponentialFrecencyScorer(storage: fakeStorage, params: frecencyParameters)
        let now = BeamDate.now
        let later = Date(timeInterval: Double(halfLife), since: now)
        // non pre exisiting score insertion
        scorer.update(id: urlIds[0], value: 1, eventType: .webSearchBar, date: now, paramKey: .webReadingTime30d0)
        try expectFrecencyScoreInStorage((urlIds[0], .webReadingTime30d0), value: 2, lastTimestamp: now, halfLife: halfLife)
        // pre existing score update
        scorer.update(id: urlIds[0], value: 1, eventType: .webSearchBar, date: later, paramKey: .webReadingTime30d0)
        try expectFrecencyScoreInStorage((urlIds[0], .webReadingTime30d0), value: 2 + 0.5 * 2, lastTimestamp: later, halfLife: halfLife)

        // no pre exisiting score insertion
        scorer.update(id: urlIds[1], value: 1, eventType: .webLinkActivation, date: now, paramKey: .webVisit30d0)
        try expectFrecencyScoreInStorage((urlIds[1], .webVisit30d0), value: 1, lastTimestamp: now, halfLife: halfLife)

        // score inserted into precise score name does not pollute other score name
        XCTAssertNil(try scorer.storage.fetchOne(id: urlIds[1], paramKey: .webReadingTime30d0), "no score value")
        XCTAssertNil(try scorer.storage.fetchOne(id: urlIds[0], paramKey: .webVisit30d0), "no score value")

        // checking that sorting key works for a 0 score
        scorer.update(id: urlIds[2], value: 0, eventType: .webLinkActivation, date: now, paramKey: .webVisit30d0)
        try expectFrecencyScoreInStorage((urlIds[2], .webVisit30d0), value: 0, lastTimestamp: now, halfLife: halfLife)
    }

    func testBatchScorer() throws {
        func checkStore(store: FrecencyStorage, paramKey: FrecencyParamKey, urlId: UUID, expectedValue: Float, expectedDate: Date) throws {
            let score = try XCTUnwrap(try? store.fetchOne(id: urlId, paramKey: paramKey))
            XCTAssertEqual(score.lastScore, expectedValue)
            XCTAssertEqual(score.lastTimestamp, expectedDate)

        }
        let halfLife = try XCTUnwrap(FrecencyParameters[.webVisit30d0]?.halfLife)
        let now = BeamDate.now
        let store = FakeFrecencyStorage()
        let urlIds = [UUID(), UUID()]
        let score = FrecencyScore(id: urlIds[0], lastTimestamp: now, lastScore: 2, halfLife: halfLife)
        try store.save(score: score, paramKey: .webVisit30d0)
        try store.save(score: score, paramKey: .webReadingTime30d0)
        let scorer = BatchFrecencyUpdater(frencencyStore: store)

        scorer.add(urlId: urlIds[0], date: now + Double(halfLife), eventType: .webLinkActivation)
        scorer.add(urlId: urlIds[1], date: now, eventType: .webLinkActivation)
        scorer.add(urlId: urlIds[1], date: now - Double(halfLife), eventType: .webLinkActivation)
        scorer.saveAll()

        //case 0: metrics other than visitCount are not touched
        try checkStore(store: store, paramKey: .webReadingTime30d0, urlId: urlIds[0], expectedValue: 2, expectedDate: now)
        //case 1: metric of url already in db
        try checkStore(store: store, paramKey: .webVisit30d0, urlId: urlIds[0], expectedValue: 2, expectedDate: now + Double(halfLife))
        //case 2: metric of newly met url
        try checkStore(store: store, paramKey: .webVisit30d0, urlId: urlIds[1], expectedValue: 1.5, expectedDate: now)
    }
}
