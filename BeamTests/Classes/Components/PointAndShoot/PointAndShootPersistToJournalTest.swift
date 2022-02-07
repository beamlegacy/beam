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
        self.pns.point(paragraphTarget, "placeholder string", "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget.id, paragraphTarget, "placeholder string", "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group2 = PointAndShoot.ShootGroup(id: "id", targets: [paragraphTarget], text: "placeholder string", href: page.url!.absoluteString, shapeCache: .init())
        let expectation = XCTestExpectation(description: "point and shoot addShootToNote")
        self.pns.addShootToNote(targetNote: page.activeNote, group: group2, completion: {
            XCTAssertEqual(self.pns.collectedGroups.count, 1)
            XCTAssertEqual(self.pns.collectedGroups.first?.targets.count, 1)
            XCTAssertEqual(self.pns.collectedGroups.first?.targets.first?.html, paragraphTarget.html)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }

    // swiftlint:disable:next function_body_length
    func testTwoShootsToTwoDifferentCards() throws {
        guard let page = self.testPage else {
            XCTFail("test page not found")
            return
        }
        // Add Paragraph 1 to Note 1
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>",
            animated: false
        )
        // Point
        self.pns.point(paragraphTarget, "placeholder string", "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget.id, paragraphTarget, "placeholder string", "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group = PointAndShoot.ShootGroup(id: "id", targets: [paragraphTarget], text: "placeholder string", href: page.url!.absoluteString, shapeCache: .init())
        let expectation = XCTestExpectation(description: "point and shoot addShootToNote")
        self.pns.addShootToNote(targetNote: page.activeNote, group: group, completion: {
            XCTAssertEqual(self.pns.collectedGroups.count, 1)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)

        // Add Paragraph 2 to Note 2
        let paragraphTarget2: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph2</p>",
            animated: false
        )
        // Point
        self.pns.point(paragraphTarget2, "placeholder string", "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget2.id, paragraphTarget2, "placeholder string", "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // Add shoot to note
        let group2 = PointAndShoot.ShootGroup(id: "id", targets: [paragraphTarget2], text: "placeholder string", href: page.url!.absoluteString, shapeCache: .init())
        let expectation2 = XCTestExpectation(description: "point and shoot addShootToNote")
        self.pns.addShootToNote(targetNote: page.activeNote, group: group2, completion: {
            XCTAssertEqual(self.pns.collectedGroups.count, 2)
            expectation2.fulfill()
        })
        wait(for: [expectation2], timeout: 10.0)
    }

    func testAddingToNotExistingNote() throws {
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
        self.pns.point(paragraphTarget, "placeholder string", "https://pnsTest.co")
        // Shoot
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.isAltKeyDown = true
        self.pns.pointShoot(paragraphTarget.id, paragraphTarget, "placeholder string", "https://pnsTest.co")
        XCTAssertNotNil(self.pns.activeShootGroup)

        // confirm a known existing note exists:
        let knownExisitingNote = self.page?.getNote(fromTitle: self.page.activeNote.title)
        XCTAssertNil(knownExisitingNote)
        // confirm note doesn't exist:
        let nonExistentNote = self.page?.getNote(fromTitle: "fake non existent note title")
        XCTAssertNil(nonExistentNote)

        // Try to add to note existent note
        let group = PointAndShoot.ShootGroup(id: "id", targets: [paragraphTarget], text: "placeholder string", href: page.url!.absoluteString, shapeCache: .init())
        let expectation = XCTestExpectation(description: "point and shoot addShootToNote")
        self.pns.addShootToNote(targetNote: BeamNote(title: "fake non existent note title"), group: group, completion: {
            // Expect it to still work.
            XCTAssertEqual(self.pns.collectedGroups.count, 1)
            XCTAssertEqual(self.pns.collectedGroups.first?.targets.count, 1)
            XCTAssertEqual(self.pns.collectedGroups.first?.targets.first?.html, paragraphTarget.html)
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
    }
}
