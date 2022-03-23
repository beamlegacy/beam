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
    func test() throws {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: "2001-01-01T13:10:21+000")!
        let truncated = try XCTUnwrap(date.dayTruncated)
        XCTAssertEqual(truncated + 13 * 60 * 60 + 10 * 60 + 21, date)
    }
}
