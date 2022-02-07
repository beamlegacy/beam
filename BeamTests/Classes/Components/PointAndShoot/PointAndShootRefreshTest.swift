//
//  PointAndShootRefreshTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootRefreshTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testRefresh_setMouseLocation() throws {
        let mouseLocation = NSPoint(x: 201, y: 202)
        let modifiers: NSEvent.ModifierFlags = [.option]
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))
        self.pns.refresh(mouseLocation, modifiers)
        XCTAssertEqual(self.pns.mouseLocation, mouseLocation)
    }

    func testRefresh_updateMouseLocation() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = [.option]

        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 201, y: 202))

        self.pns.refresh(NSPoint(x: 2001, y: 2002), modifiers)
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 2001, y: 2002))
    }

    func testRefresh_selectToShoot() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = [.option]
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )

        self.pns.activeSelectGroup = PointAndShoot.ShootGroup(id: "point-uuid", targets: [target], text: "placeholder text", href: "https://pnshref.co", shapeCache: .init())
        self.pns.hasActiveSelection = true

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertNotNil(self.pns.activeShootGroup)
    }

    func testRefresh_selectToShoot_withoutActiveSelection() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = [.option]
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )

        self.pns.activeSelectGroup = PointAndShoot.ShootGroup(id: "point-uuid", targets: [target], text: "placeholder text", href: "https://pnshref.co", shapeCache: .init())
        self.pns.hasActiveSelection = false

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testRefresh_selectToShoot_withoutActiveSelectionGroup() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = [.option]
        self.pns.hasActiveSelection = true

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testRefresh_selectToShoot_withoutOption() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = []
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )

        self.pns.activeSelectGroup = PointAndShoot.ShootGroup(id: "point-uuid", targets: [target], text: "placeholder text", href: "https://pnshref.co", shapeCache: .init())
        self.pns.hasActiveSelection = true

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testRefresh_selectToShoot_withMultipleModifiers() throws {
        XCTAssertEqual(self.pns.mouseLocation, NSPoint(x: 0, y: 0))

        let modifiers: NSEvent.ModifierFlags = [.option, .command]
        let target: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>",
            animated: false
        )

        self.pns.activeSelectGroup = PointAndShoot.ShootGroup(id: "point-uuid", targets: [target], text: "placeholder text", href: "https://pnshref.co", shapeCache: .init())
        self.pns.hasActiveSelection = true

        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.refresh(NSPoint(x: 201, y: 202), modifiers)
        XCTAssertNotNil(self.pns.activeShootGroup)
    }
}
