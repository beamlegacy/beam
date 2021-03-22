//
//  MathsTests.swift
//  BeamTests
//
//  Created by Remi Santos on 09/03/2021.
//

import Foundation
import XCTest

@testable import Beam

class MathsTests: XCTestCase {

    func testClamp() {
        let min = -10
        let max = 20
        XCTAssertEqual(0.clamp(min, max), 0)

        XCTAssertEqual((-10).clamp(min, max), -10)
        XCTAssertEqual((20).clamp(min, max), 20)

        XCTAssertEqual((-11).clamp(min, max), -10)
        XCTAssertEqual((21).clamp(min, max), 20)
    }

    func testClampInLoop() {
        let min = -10
        let max = 20
        XCTAssertEqual(0.clampInLoop(min, max), 0)

        XCTAssertEqual((-10).clampInLoop(min, max), -10)
        XCTAssertEqual((20).clampInLoop(min, max), 20)

        XCTAssertEqual((-11).clampInLoop(min, max), 20)
        XCTAssertEqual((21).clampInLoop(min, max), -10)
    }

}
