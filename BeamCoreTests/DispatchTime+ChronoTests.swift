import XCTest
import Foundation
@testable import BeamCore

class DispatchTimeChronoTests: XCTestCase {
    func testEndOfChrono() {
        var (elapsedTime, timeUnit) = computeTimeInterval(startTimeNanoseconds: 0, endTimeNanoseconds: 30)

        XCTAssertEqual(elapsedTime, 30)
        XCTAssertEqual(timeUnit, DispatchTime.TimeUnit.ns)

        (elapsedTime, timeUnit) = computeTimeInterval(startTimeNanoseconds: 0, endTimeNanoseconds: 1_042)

        XCTAssertEqual(elapsedTime, 1)
        XCTAssertEqual(timeUnit, DispatchTime.TimeUnit.µs)

        (elapsedTime, timeUnit) = computeTimeInterval(startTimeNanoseconds: 0, endTimeNanoseconds: 1_000_042)

        XCTAssertEqual(elapsedTime, 1)
        XCTAssertEqual(timeUnit, DispatchTime.TimeUnit.ms)

        (elapsedTime, timeUnit) = computeTimeInterval(startTimeNanoseconds: 0, endTimeNanoseconds: 1_000_000_042)

        XCTAssertEqual(elapsedTime, 1)
        XCTAssertEqual(timeUnit, DispatchTime.TimeUnit.s)
    }
}
