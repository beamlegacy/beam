//
//  PointAndShootShootGroupTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootShootGroupTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    let id = UUID().uuidString
    func testShootGroup_updateTarget_rect() throws {
        let initialTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        var group = PointAndShoot.ShootGroup("point-uuid", [initialTarget], "placeholder text", "https://pnshref.co", shapeCache: .init())

        let newTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 345601, y: 10802, width: 301, height: 302),
            mouseLocation: NSPoint(x: 212301, y: 999902),
            html: "<p>wow such paragraph</p>",
            animated: false
        )

        group.updateTarget(newTarget)

        let updatedTarget = group.targets[0]
        XCTAssertEqual(updatedTarget.rect, newTarget.rect)
    }

    func testShootGroup_updateTarget_mouseLocation() throws {
        let initialTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        var group = PointAndShoot.ShootGroup("point-uuid", [initialTarget], "placeholder text", "https://pnshref.co", shapeCache: .init())

        let newTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 345601, y: 10802, width: 301, height: 302),
            mouseLocation: NSPoint(x: 212301, y: 999902),
            html: "<p>wow such paragraph</p>",
            animated: false
        )

        group.updateTarget(newTarget)

        let updatedTarget = group.targets[0]
        XCTAssertEqual(updatedTarget.rect, newTarget.rect)
        // Mouse location shouldn't take the new mouseLocation, but instead move in the same direction equal to the new rect x, y position
        XCTAssertEqual(updatedTarget.mouseLocation, NSPoint(x: 345701.0, y: 10902.0))
    }

    func testShootGroup_updateTarget_mismatchedId() throws {
        let initialTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        var group = PointAndShoot.ShootGroup("point-uuid", [initialTarget], "placeholder text", "https://pnshref.co", shapeCache: .init())

        let newTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 345601, y: 10802, width: 301, height: 302),
            mouseLocation: NSPoint(x: 212301, y: 999902),
            html: "<p>wow such paragraph</p>",
            animated: false
        )

        group.updateTarget(newTarget)

        let updatedTarget = group.targets[0]

        // If ids don't match, don't update to newTarget values
        XCTAssertEqual(updatedTarget.mouseLocation, initialTarget.mouseLocation)
    }

    func testShootGroup_updateTarget_html() throws {
        let initialTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        var group = PointAndShoot.ShootGroup("point-uuid", [initialTarget], "placeholder text", "https://pnshref.co", shapeCache: .init())

        let newTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: id,
            rect: NSRect(x: 345601, y: 10802, width: 301, height: 302),
            mouseLocation: NSPoint(x: 212301, y: 999902),
            html: "<p>wow such paragraph</p>",
            animated: false
        )

        group.updateTarget(newTarget)

        let updatedTarget = group.targets[0]

        // matching ids should not update the html
        XCTAssertEqual(updatedTarget.html, initialTarget.html)
    }

}
