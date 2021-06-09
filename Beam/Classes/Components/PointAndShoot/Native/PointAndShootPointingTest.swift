//
//  PointAndShootPointingTest.swift
//  BeamTests
//
//  Created by Stef Kors on 08/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootPointingTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testPointAndUnpoint() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>"
        )
        self.pns.point(target: target)
        XCTAssertEqual(self.pns.isPointing, true)
        XCTAssertEqual(self.helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(self.testUI.events[1], "drawPoint Target(area: (101.0, 102.0, 301.0, 302.0), quoteId: nil, "
                        + "mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")")

        self.pns.unpoint()
        XCTAssertEqual(self.pns.isPointing, false)
        XCTAssertEqual(self.helperCountUIEvents("drawPoint"), 1)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
