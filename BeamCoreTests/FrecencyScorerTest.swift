//
//  FrecencyScorerTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 18/06/2021.
//

import XCTest

@testable import BeamCore

typealias Table = [UInt64: FrecencyScore]
typealias ScoreData = [FrecencyParamKey: Table]

class FrecencyScorerTest: XCTestCase {
    class FakeFrecencyStorage: FrecencyStorage {
        var data: ScoreData = ScoreData()

        func fetchOne(id: FrecencyScoreIdKey, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
            guard let urlId = id as? UInt64 else { return nil }
            return data[paramKey]?[urlId]
        }
        func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
            guard let urlId = score.id as? UInt64 else { return }
            if data[paramKey] != nil {
                data[paramKey]?[urlId] = score
            } else {
                data[paramKey] = [urlId: score]
            }
        }
    }

    var fakeStorage = FakeFrecencyStorage()

    override func setUp() {
        fakeStorage = FakeFrecencyStorage()
    }

    typealias StorageKey = (urlId: UInt64, frecencyParam: FrecencyParamKey)
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
        XCTAssertEqual(score?.sortValue,
                       log(value) + Float(lastTimestamp.timeIntervalSinceReferenceDate) * log(2) / halfLife,
                       file: file, line: line)
    }

    /// Test frecency score computation and insertion.
    func testScorer() throws {
        let halfLife = Float(10.0)

        let frecencyParameters: [FrecencyParamKey: FrecencyParam] = [
            .webReadingTime30d0: FrecencyParam(key: .webReadingTime30d0, eventWeights: [.webSearchBar: 2.0], halfLife: halfLife),
            .webVisit30d0: FrecencyParam(key: .webVisit30d0, eventWeights: [.webSearchBar: 2.0], halfLife: halfLife)
        ]
        let urlIds = (0...2).map { UInt64($0) as FrecencyScoreIdKey }
        let scorer = ExponentialFrecencyScorer(storage: fakeStorage, params: frecencyParameters)
        let now = BeamDate.now
        let later = Date(timeInterval: Double(halfLife), since: now)
        // non pre exisiting score insertion
        scorer.update(id: urlIds[0], value: 1, eventType: .webSearchBar, date: now, paramKey: .webReadingTime30d0)
        try expectFrecencyScoreInStorage((0, .webReadingTime30d0), value: 2, lastTimestamp: now, halfLife: halfLife)
        // pre existing score update
        scorer.update(id: urlIds[0], value: 1, eventType: .webSearchBar, date: later, paramKey: .webReadingTime30d0)
        try expectFrecencyScoreInStorage((0, .webReadingTime30d0), value: 2 + 0.5 * 2, lastTimestamp: later, halfLife: halfLife)

        // no pre exisiting score insertion
        scorer.update(id: urlIds[1], value: 1, eventType: .webLinkActivation, date: now, paramKey: .webVisit30d0)
        try expectFrecencyScoreInStorage((1, .webVisit30d0), value: 1, lastTimestamp: now, halfLife: halfLife)

        // score inserted into precise score name does not pollute other score name
        XCTAssertNil(try scorer.storage.fetchOne(id: urlIds[1], paramKey: .webReadingTime30d0), "no score value")
        XCTAssertNil(try scorer.storage.fetchOne(id: urlIds[0], paramKey: .webVisit30d0), "no score value")

        // checking that sorting key works for a 0 score
        scorer.update(id: urlIds[2], value: 0, eventType: .webLinkActivation, date: now, paramKey: .webVisit30d0)
        try expectFrecencyScoreInStorage((2, .webVisit30d0), value: 0, lastTimestamp: now, halfLife: halfLife)
    }
}
