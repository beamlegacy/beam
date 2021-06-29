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

    func testScorer() throws {
        //test frecency score computation and insertion

        let halfLife = Float(10.0)
        func testScoreValue(_ storage: FrecencyStorage, _ urlId: UInt64, _ paramsKey: FrecencyParamKey, _ value: Float, _ date: Date) throws {
            let score = try storage.fetchOne(urlId: urlId, paramKey: paramsKey)
            XCTAssertEqual(score?.lastScore, value, "wrong last score value")
            XCTAssertEqual(score?.lastTimestamp, date, "wrong last timestamp value")
            XCTAssertEqual(score?.sortValue, log(value) + Float(date.timeIntervalSinceReferenceDate) * log(2) / halfLife, "wrong sort value")
        }

        let testfrecencyParameters: [FrecencyParamKey: FrecencyParam] = [
            .readingTime30d0: FrecencyParam(key: .readingTime30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife),
            .visit30d0: FrecencyParam(key: .visit30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife)
        ]

        let scorer = ExponentialFrecencyScorer(storage: FakeFrecencyStorage(), params: testfrecencyParameters)
        let now = Date()
        let later = Date(timeInterval: Double(halfLife), since: now)
        //non pre exisiting score insertion
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: now, paramKey: .readingTime30d0)
        try testScoreValue(scorer.storage, 0, .readingTime30d0, 2, now)
        //pre existing score update
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: later, paramKey: .readingTime30d0)
        try testScoreValue(scorer.storage, 0, .readingTime30d0, 2 + 0.5 * 2, later)

        //no pre exisiting score insertion
        scorer.update(urlId: 1, value: 1, visitType: .linkActivation, date: now, paramKey: .visit30d0)
        try testScoreValue(scorer.storage, 1, .visit30d0, 1, now)

        //score inserted into precise score name does not pollute other score name
        XCTAssertNil(try scorer.storage.fetchOne(urlId: 1, paramKey: .readingTime30d0), "no score value")
        XCTAssertNil(try scorer.storage.fetchOne(urlId: 0, paramKey: .visit30d0), "no score value")

        //checking that sorting key works for a 0 score
        scorer.update(urlId: 2, value: 0, visitType: .linkActivation, date: now, paramKey: .visit30d0)
        try testScoreValue(scorer.storage, 2, .visit30d0, 0, now)

    }
}
