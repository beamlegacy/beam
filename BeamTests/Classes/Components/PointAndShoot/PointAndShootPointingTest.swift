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

    func testPoint() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        // Point
        self.pns.point(target, "placeholder string", "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activePointGroup)
    }
}
