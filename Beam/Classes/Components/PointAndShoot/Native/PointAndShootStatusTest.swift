//
//  PointAndShootStatusTest.swift
//  BeamTests
//
//  Created by Stef Kors on 08/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootStatusTest: PointAndShootTest {
    override func setUpWithError() throws {
        initTestBed()
    }

    let optionsList: [[PointAndShootStatus]] = [
        [.none, .none],
        [.none, .shooting],
        [.none, .pointing],
        [.shooting, .none],
        [.shooting, .shooting],
        [.shooting, .pointing],
        [.pointing, .none],
        [.pointing, .shooting],
        [.pointing, .pointing]
    ]

    func testMatrixOfAllOptions() throws {
        for options in optionsList {
            let optionA = options[0]
            let optionB = options[1]
            XCTAssertEqual(self.pns.status, .none)
            self.pns.status = optionA
            XCTAssertEqual(self.pns.status, optionA)
            self.pns.status = optionB
            XCTAssertEqual(self.pns.status, optionB)
            self.pns.status = .none
        }
    }
}
