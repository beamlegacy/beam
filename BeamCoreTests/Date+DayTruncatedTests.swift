//
//  Date+DayTruncatedTests.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 03/03/2022.
//

import XCTest
import Foundation
@testable import BeamCore

class DateTruncateTest: XCTestCase {
    func testUtcTruncated() throws {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2001-01-01T13:10:21+000")!
        let truncated = try XCTUnwrap(date.utcDayTruncated)
        XCTAssertEqual(truncated + 13 * 60 * 60 + 10 * 60 + 21, date)
    }
    func testLocalDayString() {
        BeamDate.freeze("2001-01-01T01:30:00+000")
        let now = BeamDate.now
        XCTAssertEqual(now.localDayString(timeZone: TimeZone(secondsFromGMT: 0)), "2001-01-01")
        XCTAssertEqual(now.localDayString(timeZone: TimeZone(secondsFromGMT: -2 * 60 * 60)), "2000-12-31")
        BeamDate.reset()
    }
}
