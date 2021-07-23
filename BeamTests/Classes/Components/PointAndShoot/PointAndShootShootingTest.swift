//
//  PointAndShootShootingTest.swift
//  BeamTests
//
//  Created by Stef Kors on 08/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootShootingTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
        self.pns.mouseLocation = NSPoint(x: 201, y: 202)
    }

    func testFailShootWithoutActivePointGroup() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(target.id, target, "https://pnsTest.co")
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testFailShootWithoutAltKeyDown() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )
        // Point
        self.pns.point(target, "https://pnsTest.co")
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(target.id, target, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)
    }

    func testShootAndUnshoot() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: self.pns.mouseLocation,
            html: "<p>Pointed text</p>",
            animated: false
        )
        // Point
        self.pns.point(target, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(target.id, target, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)
    }

    func testDismissedShoot() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: self.pns.mouseLocation,
            html: "<p>Pointed text</p>",
            animated: false
        )
        // Point
        self.pns.point(target, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(target.id, target, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)
        XCTAssertEqual(self.pns.dismissedGroups.count, 0)
        self.pns.cancelShoot()
        XCTAssertNil(self.pns.activeShootGroup)
        XCTAssertEqual(self.pns.dismissedGroups.count, 1)
    }

    func testCompletedShoot() throws {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: self.pns.mouseLocation,
            html: "<p>Pointed text</p>",
            animated: false
        )
        // Point
        self.pns.point(target, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(target.id, target, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        self.pns.addShootToNote(noteTitle: "Card A")
        XCTAssertEqual(self.testPage?.events.count, 3)
        XCTAssertEqual(self.testPage?.events[2], "addToNote true")
    }
}
