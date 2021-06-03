//
//  Range+BeamTests.swift
//  BeamTests
//
//  Created by Remi Santos on 02/06/2021.
//

import XCTest
@testable import Beam

class Range_BeamTests: XCTestCase {

    func testClosedRangeJoin() {

        let range = 10...20
        // Append after
        XCTAssertEqual(range.join(15...25), 10...25)
        XCTAssertEqual(range.join(20...25), 10...25)
        XCTAssertEqual(range.join(21...25), 10...25)
        XCTAssertEqual((0...0).join(1...1), 0...1)

        // Prepend before
        XCTAssertEqual(range.join(5...15), 5...20)
        XCTAssertEqual(range.join(5...10), 5...20)
        XCTAssertEqual(range.join(5...9), 5...20)
        XCTAssertEqual((1...1).join(0...0), 0...1)

        // can't join
        XCTAssertEqual(range.join(5...8), range)
        XCTAssertEqual(range.join(22...25), range)
    }

    func testRangeJoin() {

        let range = 10..<20
        // Append after
        XCTAssertEqual(range.join(15..<25), 10..<25)
        XCTAssertEqual(range.join(20..<25), 10..<25)
        XCTAssertEqual(range.join(21..<25), range)
        XCTAssertEqual((0..<0).join(1..<1), 0..<0)

        // Prepend before
        XCTAssertEqual(range.join(5..<15), 5..<20)
        XCTAssertEqual(range.join(5..<10), 5..<20)
        XCTAssertEqual(range.join(5..<9), 5..<20)
        XCTAssertEqual((1..<1).join(0..<0), 1..<1)

        // can't join
        XCTAssertEqual(range.join(5..<8), range)
        XCTAssertEqual(range.join(22..<25), range)
    }

}
