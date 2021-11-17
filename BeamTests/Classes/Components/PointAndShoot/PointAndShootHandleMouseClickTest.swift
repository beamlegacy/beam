//
//  PointAndShootHandleMouseClickTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootHandleMouseClickTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testHandleMouseClick_InsideTarget() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        self.pns.activeShootGroup = PointAndShoot.ShootGroup("point-uuid", [target], "placeholder string", "https://pnshref.co", shapeCache: .init())
        XCTAssertNotNil(self.pns.activeShootGroup)

        let mouseLocation = NSPoint(x: 201, y: 202)
        self.pns.handleMouseClick(mouseLocation)
        XCTAssertNotNil(self.pns.activeShootGroup)
    }

    func testHandleMouseClick_OutsideTarget() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        self.pns.activeShootGroup = PointAndShoot.ShootGroup("point-uuid", [target], "placeholder string", "https://pnshref.co", shapeCache: .init())
        XCTAssertNotNil(self.pns.activeShootGroup)

        let mouseLocation = NSPoint(x: 501, y: 502)
        self.pns.handleMouseClick(mouseLocation)
        XCTAssertNil(self.pns.activeShootGroup)
    }
}
