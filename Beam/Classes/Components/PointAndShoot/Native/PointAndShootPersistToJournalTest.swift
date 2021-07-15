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
        // Add Paragraph 1 to Card 1
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>"
        )

        // Point
        self.pns.point(target: paragraphTarget, href: self.pns.page.url!.string)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [paragraphTarget], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()

        // Add shoot to note
        let text: [BeamText] = html2Text(url: self.url, html: paragraphTarget.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil {
                    let noteInfo = NoteInfo(id: UUID(), title: self.page.activeNote)
                    self.pns.complete(noteInfo: noteInfo, group: self.pns.activeShootGroup!)
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

        XCTAssertEqual(self.pns.shootGroups.count, 1)
        XCTAssertEqual(self.pns.shootGroups.first?.targets.count, 1)
        XCTAssertEqual(self.pns.shootGroups.first?.targets.first?.html, paragraphTarget.html)
    }

    // swiftlint:disable:next function_body_length
    func testTwoShootsToTwoDifferentCards() throws {
        // Add Paragraph 1 to Card 1
        let paragraphTarget: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph1</p>"
        )

        // Point
        self.pns.point(target: paragraphTarget, href: self.pns.page.url!.string)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [paragraphTarget], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()

        // Add shoot to note
        let text: [BeamText] = html2Text(url: self.url, html: paragraphTarget.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil {
                    let noteInfo = NoteInfo(id: UUID(), title: self.page.activeNote)
                    self.pns.complete(noteInfo: noteInfo, group: self.pns.activeShootGroup!)
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

        XCTAssertEqual(self.pns.shootGroups.count, 1)
        XCTAssertEqual(self.pns.shootGroups.first?.targets.count, 1)
        XCTAssertEqual(self.pns.shootGroups.first?.targets.first?.html, paragraphTarget.html)

        // Add Paragraph 2 to Card 2
        let paragraphTarget2: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<p>paragraph2</p>"
        )
        let page = self.testPage!
        page.activeNote = "Card B"
        page.testNotes["Card B"] = BeamNote(title: "Card B")

        // Point
        self.pns.point(target: paragraphTarget2, href: self.pns.page.url!.string)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [paragraphTarget2], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()

        // Add shoot to note
        let text2: [BeamText] = html2Text(url: self.url, html: paragraphTarget2.html)
        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text2, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if quotes.first != nil {
                    let noteInfo = NoteInfo(id: UUID(), title: self.page.activeNote)
                    self.pns.complete(noteInfo: noteInfo, group: self.pns.activeShootGroup!)
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }

        XCTAssertEqual(self.pns.shootGroups.count, 2)
        XCTAssertEqual(self.pns.shootGroups.last?.targets.count, 1)
        XCTAssertEqual(self.pns.shootGroups.last?.targets.last?.html, paragraphTarget2.html)
    }
}
