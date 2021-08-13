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

        func fetchOne(urlId: UInt64, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
            return data[paramKey]?[urlId]
        }
        func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
            if data[paramKey] != nil {
                data[paramKey]?[score.urlId] = score
            } else {
                data[paramKey] = [score.urlId: score]
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
        let score = try self.fakeStorage.fetchOne(urlId: key.urlId, paramKey: key.frecencyParam)
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
            .readingTime30d0: FrecencyParam(key: .readingTime30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife),
            .visit30d0: FrecencyParam(key: .visit30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife)
        ]

        let scorer = ExponentialFrecencyScorer(storage: fakeStorage, params: frecencyParameters)
        let now = BeamDate.now
        let later = Date(timeInterval: Double(halfLife), since: now)
        // non pre exisiting score insertion
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: now, paramKey: .readingTime30d0)
        try expectFrecencyScoreInStorage((0, .readingTime30d0), value: 2, lastTimestamp: now, halfLife: halfLife)
        // pre existing score update
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: later, paramKey: .readingTime30d0)
        try expectFrecencyScoreInStorage((0, .readingTime30d0), value: 2 + 0.5 * 2, lastTimestamp: later, halfLife: halfLife)

        // no pre exisiting score insertion
        scorer.update(urlId: 1, value: 1, visitType: .linkActivation, date: now, paramKey: .visit30d0)
        try expectFrecencyScoreInStorage((1, .visit30d0), value: 1, lastTimestamp: now, halfLife: halfLife)

        // score inserted into precise score name does not pollute other score name
        XCTAssertNil(try scorer.storage.fetchOne(urlId: 1, paramKey: .readingTime30d0), "no score value")
        XCTAssertNil(try scorer.storage.fetchOne(urlId: 0, paramKey: .visit30d0), "no score value")

        // checking that sorting key works for a 0 score
        scorer.update(urlId: 2, value: 0, visitType: .linkActivation, date: now, paramKey: .visit30d0)
        try expectFrecencyScoreInStorage((2, .visit30d0), value: 0, lastTimestamp: now, halfLife: halfLife)
    }
}
