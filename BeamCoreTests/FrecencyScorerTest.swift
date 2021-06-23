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

        func getOne(urlId: UInt64, paramKey: FrecencyParamKey) -> FrecencyScore? {
            return data[paramKey]?[urlId]
        }
        func getAll(urlIds: [UInt64], paramKey: FrecencyParamKey) -> [FrecencyScore] {
            return urlIds.compactMap { getOne(urlId: $0, paramKey: paramKey) }
        }
        func save(score: FrecencyScore, paramKey: FrecencyParamKey) {
            if data[paramKey] != nil {
                data[paramKey]?[score.urlId] = score
            } else {
                data[paramKey] = [score.urlId: score]
            }
        }
    }

    func testScorer() throws {
        //test frecency score computation and insertion

        func testScoreValue(_ storage: FrecencyStorage, _ urlId: UInt64, _ paramsKey: FrecencyParamKey, _ value: Float, _ date: Date) {
            let score = storage.getOne(urlId: urlId, paramKey: paramsKey)!
            XCTAssertEqual(score.value, value)
            XCTAssertEqual(score.timeStamp, date)
        }

        let halfLife = Float(10.0)
        let testfrecencyParameters: [FrecencyParamKey: FrecencyParam] = [
            .readingTime30d0: FrecencyParam(key: .readingTime30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife),
            .visit30d0: FrecencyParam(key: .visit30d0, visitWeights: [.searchBar: 2.0], halfLife: halfLife)
        ]

        let scorer = ExponentialFrecencyScorer(storage: FakeFrecencyStorage(), params: testfrecencyParameters)
        let now = Date()
        let later = Date(timeInterval: Double(halfLife), since: now)

        //non pre exisiting score insertion
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: now, paramKey: .readingTime30d0)
        testScoreValue(scorer.storage, 0, .readingTime30d0, 2, now)
        //pre existing score update
        scorer.update(urlId: 0, value: 1, visitType: .searchBar, date: later, paramKey: .readingTime30d0)
        testScoreValue(scorer.storage, 0, .readingTime30d0, 2 + 0.5 * 2, later)

        //no pre exisiting score insertion
        scorer.update(urlId: 1, value: 1, visitType: .linkActivation, date: now, paramKey: .visit30d0)
        testScoreValue(scorer.storage, 1, .visit30d0, 1, now)

        //score inserted into precise score name does not pollute other score name
        XCTAssertNil(scorer.storage.getOne(urlId: 1, paramKey: .readingTime30d0), "no score value")
        XCTAssertNil(scorer.storage.getOne(urlId: 0, paramKey: .visit30d0), "no score value")
    }
}
