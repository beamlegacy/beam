//
//  Calendar+AdditionsTests.swift
//  BeamTests
//
//  Created by Remi Santos on 17/08/2021.
//

import XCTest
@testable import Beam

class Calendar_AdditionsTests: XCTestCase {

    func testNumberOfDaysInWeek() throws {
        let gregorianCal = Calendar(identifier: .gregorian)
        let date = Date()
        XCTAssertEqual(gregorianCal.numberOfDaysInWeek(for: date), 7)
        let japaneseCal = Calendar(identifier: .japanese)
        XCTAssertEqual(japaneseCal.numberOfDaysInWeek(for: date), 7)
    }
    

    func testStartOfMonth() {
        let cal = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 0)
        let expected = cal.date(from: DateComponents(year: 1970, month: 1, day: 1))
        XCTAssertEqual(cal.startOfMonth(for: date), expected)

        let otherDate = cal.date(from: DateComponents(calendar: cal, year: 2020, month: 6, day: 16)) ?? Date() // 16 June 2020 (beam company creation)
        let expectedOther = cal.date(from: DateComponents(year: 2020, month: 6, day: 1))
        XCTAssertEqual(cal.startOfMonth(for: otherDate), expectedOther)
    }

    func testEndOfMonth() {
        let cal = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 0)
        let expected = cal.date(from: DateComponents(year: 1970, month: 1, day: 31))
        XCTAssertEqual(cal.endOfMonth(for: date), expected)

        let otherDate = cal.date(from: DateComponents(calendar: cal, year: 2020, month: 6, day: 16)) ?? Date() // 16 June 2020 (beam company creation)
        let expectedOther = cal.date(from: DateComponents(year: 2020, month: 6, day: 30))
        XCTAssertEqual(cal.endOfMonth(for: otherDate), expectedOther)
    }

}
