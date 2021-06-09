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
    }

    func testShootAndUnshoot() throws {
        let target1: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>"
        )
        // Point
        self.pns.point(target: target1)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [target1], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()
        XCTAssertEqual(self.pns.status, .shooting)
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 2)
        XCTAssertEqual(self.testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(self.pns.activeShootGroup?.targets.count, 1)   // One current shoot
        XCTAssertEqual(self.pns.shootGroups.count, 0)         // But not validated yet

        // Cancel shoot
        self.pns.resetStatus()
        XCTAssertEqual(self.pns.status, .none)           // Disallow unpoint while shooting
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 2)
        XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(self.pns.activeShootGroup == nil, true)       // No current shoot
        XCTAssertEqual(self.pns.shootGroups.count, 0)         // No shoot group memorized
    }

    func testCompleteSingleShoot() throws {
        let target1: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>"
        )
        // Point
        self.pns.point(target: target1)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [target1], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()
        XCTAssertEqual(self.pns.status, .shooting)
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 2)
        XCTAssertEqual(self.testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(self.pns.activeShootGroup?.targets.count, 1)   // One current shoot
        XCTAssertEqual(self.pns.shootGroups.count, 0)         // But not validated yet

        // Complete shoot
        self.pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!, group: self.pns.activeShootGroup!)
        XCTAssertEqual(self.pns.status, .none)       // Disallow unpoint while shooting
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 2)
        XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(self.pns.shootGroups.count, 1)         // One shoot group memorized
    }

    func testCountUIEventsForCompleteSignleShoot() throws {
        let target1: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text</p>"
        )
        self.pns.point(target: target1)
        self.pns.draw()
        self.pns.shoot(targets: [target1], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()
        self.pns.complete(noteInfo: NoteInfo(id: nil, title: "My note"), quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!, group: self.pns.activeShootGroup!)

        let events = self.testUI.events
        let expectedEvents = [
            "clearShoots",
            "drawPoint Target(area: (101.0, 102.0, 301.0, 302.0), quoteId: nil, mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")",
            "clearPoint",
            "clearShoots",
            "createUI Target(area: (101.0, 102.0, 301.0, 302.0), quoteId: nil, mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")",
            "createGroup NoteInfo(id: nil, title: \"\") true",
            "clearShoots",
            "drawShootConfirmation Target(area: (101.0, 102.0, 301.0, 302.0), quoteId: nil, mouseLocation: (201.0, 202.0), html: \"<p>Pointed text</p>\")"
        ]
        let countDiff = events.count - expectedEvents.count
        // UI draw or clear functions shouldn't be called without change
        // Repeated draw events could cause unessesairy renders
        // TODO: update this test so this doesn't happen
        XCTAssertTrue(events.count > expectedEvents.count, "For now Point and Shoot UI is called \(countDiff) times too often")
    }

    func testCompleteTwoShoots() throws {
        // Shoot 1
        let target1: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text, iteration: 1</p>"
        )
        self.pns.point(target: target1)
        self.pns.draw()
        self.pns.shoot(targets: [target1], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()
        self.pns.complete(
            noteInfo: NoteInfo(id: nil, title: "My note"),
            quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!,
            group: self.pns.activeShootGroup!
        )

        // Shoot 2
        let target2: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>Pointed text, iteration: 2</p>"
        )
        self.pns.point(target: target2)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [target2], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()
        XCTAssertEqual(self.pns.status, .shooting)
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 2)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 7)
        XCTAssertEqual(self.testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(self.pns.activeShootGroup?.targets.count, 1)   // One current shoot
        XCTAssertEqual(self.pns.shootGroups.count, 1)         // But not validated yet

        // Complete shoot
        self.pns.complete(
            noteInfo: NoteInfo(id: nil, title: "My note"),
            quoteId: UUID(uuidString: "347271F3-A6EA-495D-859D-B0F7B807DA3C")!,
            group: self.pns.activeShootGroup!
        )

        XCTAssertEqual(self.pns.status, .none)       // Disallow unpoint while shooting
        XCTAssertEqual(helperCountUIEvents("drawPoint"), 2)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 7)
        XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
        XCTAssertEqual(self.pns.shootGroups.count, 2)         // One shoot group memorized
    }
}
