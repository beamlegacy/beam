//
//  PointAndShootPersistToJournalTest.swift
//  BeamTests
//
//  Created by Stef Kors on 08/06/2021.
//
import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootPersistToJournalTest: PointAndShootTest {
    var page: TestWebPage!

    override func setUpWithError() throws {
        initTestBed()

        self.pns.mouseLocation = NSPoint(x: 201, y: 202)
    }

    func testSingleShootToNote() throws {
        guard let page = self.testPage else {
            XCTFail("test page not found")
            return
        }
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>",
            animated: false
        )
        // Point
        self.pns.point(paragraphTarget, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget.id, paragraphTarget, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group2 = PointAndShoot.ShootGroup("id", [paragraphTarget], page.url!.absoluteString)
        self.pns.addShootToNote(noteTitle: page.activeNote, group: group2)

        XCTAssertEqual(self.pns.collectedGroups.count, 1)
        XCTAssertEqual(self.pns.collectedGroups.first?.targets.count, 1)
        XCTAssertEqual(self.pns.collectedGroups.first?.targets.first?.html, paragraphTarget.html)
    }

    // swiftlint:disable:next function_body_length
    func testTwoShootsToTwoDifferentCards() throws {
        guard let page = self.testPage else {
            XCTFail("test page not found")
            return
        }
        // Add Paragraph 1 to Card 1
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>",
            animated: false
        )
        // Point
        self.pns.point(paragraphTarget, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget.id, paragraphTarget, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group = PointAndShoot.ShootGroup("id", [paragraphTarget], page.url!.absoluteString)
        self.pns.addShootToNote(noteTitle: page.activeNote, group: group)

        XCTAssertEqual(self.pns.collectedGroups.count, 1)

        // Add Paragraph 2 to Card 2
        let paragraphTarget2: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph2</p>",
            animated: false
        )
        // Point
        self.pns.point(paragraphTarget2, "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget2.id, paragraphTarget2, "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group2 = PointAndShoot.ShootGroup("id", [paragraphTarget2], page.url!.absoluteString)
        self.pns.addShootToNote(noteTitle: page.activeNote, group: group2)

        XCTAssertEqual(self.pns.collectedGroups.count, 2)
    }
}
