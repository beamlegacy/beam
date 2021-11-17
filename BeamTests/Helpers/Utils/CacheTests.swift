//
//  CacheTests.swift
//  BeamTests
//
//  Created by Remi Santos on 21/10/2021.
//

import XCTest
@testable import Beam

class CacheTests: XCTestCase {

    func testCountLimit() {
        let cache = Cache<String, String>(countLimit: 5)
        for i in 0..<5 {
            cache["\(i)"] = "\(i)"
        }
        XCTAssertEqual(cache.numberOfValues, 5)
        XCTAssertNotNil(cache["0"])
        XCTAssertNil(cache["5"])

        for i in 5..<7 {
            cache["\(i)"] = "\(i)"
        }
        XCTAssertEqual(cache.numberOfValues, 5)
        // Cache will keep the "0" because we read it once, making its priority higher
        XCTAssertNotNil(cache["0"])
        XCTAssertNil(cache["1"])
        XCTAssertNil(cache["2"])
        XCTAssertNotNil(cache["3"])
        XCTAssertNotNil(cache["5"])
        XCTAssertNotNil(cache["6"])
    }

    func testCodability() throws {
        let cache = Cache<String, String>(countLimit: 5)
        for i in 0..<5 {
            cache["\(i)"] = "\(i)"
        }
        XCTAssertEqual(cache.countLimit, 5)
        XCTAssertNotNil(cache["0"])
        XCTAssertNotNil(cache["4"])

        let encoded = try JSONEncoder().encode(cache)
        XCTAssertNotNil(encoded)

        let decoded = try JSONDecoder().decode(Cache<String, String>.self, from: encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded.countLimit, 5)
        XCTAssertEqual(decoded.numberOfValues, 5)
        XCTAssertNotNil(cache["0"])
        XCTAssertNotNil(cache["4"])
    }

    func testRemoveAllValues() {
        let cache = Cache<String, String>(countLimit: 5)
        for i in 0..<5 {
            cache["\(i)"] = "\(i)"
        }
        XCTAssertEqual(cache.numberOfValues, 5)
        cache.removeAllValues()
        XCTAssertEqual(cache.numberOfValues, 0)
    }
}
