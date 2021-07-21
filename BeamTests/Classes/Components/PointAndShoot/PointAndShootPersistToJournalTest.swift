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
    var url: URL!
    var page: TestWebPage!

    override func setUpWithError() throws {
        initTestBed()

        self.pns.mouseLocation = NSPoint(x: 201, y: 202)

        if let page = self.testPage,
           let url = page.url {
            self.page = page
            XCTAssertEqual(url.absoluteString, "https://webpage.com")
            self.url = url
        } else {
            XCTFail("no page url available")
        }
    }

    func testSingleShootToNote() throws {
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
        let text: [BeamText] = html2Text(url: self.url, html: paragraphTarget.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil,
                   let group = self.pns.activeShootGroup {
                    self.pns.collectedGroups.append(group)
                    self.pns.activeShootGroup = nil
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

        XCTAssertEqual(self.pns.collectedGroups.count, 1)
        XCTAssertEqual(self.pns.collectedGroups.first?.targets.count, 1)
        XCTAssertEqual(self.pns.collectedGroups.first?.targets.first?.html, paragraphTarget.html)
    }

    // swiftlint:disable:next function_body_length
    func testTwoShootsToTwoDifferentCards() throws {
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
        let text: [BeamText] = html2Text(url: self.url, html: paragraphTarget.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil,
                   let group = self.pns.activeShootGroup {
                    self.pns.collectedGroups.append(group)
                    self.pns.activeShootGroup = nil
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

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
        let text2: [BeamText] = html2Text(url: self.url, html: paragraphTarget2.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text2, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil,
                   let group = self.pns.activeShootGroup {
                    self.pns.collectedGroups.append(group)
                    self.pns.activeShootGroup = nil
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

        XCTAssertEqual(self.pns.collectedGroups.count, 2)
    }
}
