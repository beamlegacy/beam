//
//  Calendar+CalculationsTests.swift
//  BeamTests
//
//  Created by Remi Santos on 17/08/2021.
//

import XCTest
@testable import Beam

class Calendar_CalculationsTests: XCTestCase {

    func numberOfDaysInWeek() throws {
        let gregorianCal = Calendar(identifier: .gregorian)
        let date = Date()
        XCTAssertEqual(gregorianCal.numberOfDaysInWeek(for: date), 7)
        let japaneseCal = Calendar(identifier: .japanese)
        XCTAssertEqual(japaneseCal.numberOfDaysInWeek(for: date), 7)
    }

}
