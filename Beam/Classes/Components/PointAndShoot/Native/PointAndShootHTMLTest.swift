//
//  PointAndShootHTMLTest.swift
//  BeamTests
//
//  Created by Stef Kors on 08/06/2021.
//
import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootHTMLTest: PointAndShootTest {
    func helperShootHtml(_ html: String) {
        let target: PointAndShoot.Target = PointAndShoot.Target(
            area: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: html
        )

        // Point
        self.pns.point(target: target)
        self.pns.draw()
        // Shoot
        self.pns.shoot(targets: [target], href: self.pns.page.url!.string)
        self.pns.status = .shooting
        self.pns.draw()

        XCTAssertEqual(helperCountUIEvents("drawPoint"), 1)
        XCTAssertEqual(helperCountUIEvents("createGroup"), 2)
        XCTAssertEqual(self.testUI.groupsUI.count, 1)    // One shoot UI
        XCTAssertEqual(self.pns.activeShootGroup?.targets.count, 1)   // One current shoot
    }

    override func setUpWithError() throws {
        initTestBed()
    }

    func testImageRelative() throws {
        XCTAssertEqual(self.testPage!.url?.absoluteString, "https://webpage.com")
        helperShootHtml("<img src=\"someImage.png\">")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                let page = self.testPage!
                let downloadManager = page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)
                XCTAssertEqual(downloadManager?.events[0], "downloaded someImage.png -- https://webpage.com with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                XCTAssertEqual(self.helperCountUIEvents("drawPoint"), 1)
                XCTAssertEqual(self.helperCountUIEvents("createGroup"), 2)
                XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
                XCTAssertEqual(self.pns.shootGroups.count, 1)         // One shoot group memorized
                done()
            }
        }
    }

    func testImageAbsolute() throws {
        XCTAssertEqual(self.testPage!.url?.absoluteString, "https://webpage.com")
        helperShootHtml("<img src=\"https://webpage.com/someImage.png\">")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                let page = self.testPage!
                let downloadManager = page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)
                XCTAssertEqual(downloadManager?.events[0], "downloaded https://webpage.com/someImage.png with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                XCTAssertEqual(self.helperCountUIEvents("drawPoint"), 1)
                XCTAssertEqual(self.helperCountUIEvents("createGroup"), 2)
                XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
                XCTAssertEqual(self.pns.shootGroups.count, 1)         // One shoot group memorized
                done()
            }
        }
    }

    func testImageExternal() throws {
        XCTAssertEqual(self.testPage!.url?.absoluteString, "https://webpage.com")
        helperShootHtml("<img src=\"https://i.imgur.com/someImage.png\">")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                let page = self.testPage!
                let downloadManager = page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)
                XCTAssertEqual(downloadManager?.events[0], "downloaded https://i.imgur.com/someImage.png with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                XCTAssertEqual(self.helperCountUIEvents("drawPoint"), 1)
                XCTAssertEqual(self.helperCountUIEvents("createGroup"), 2)
                XCTAssertEqual(self.testUI.groupsUI.count, 0)    // No more shoot UI
                XCTAssertEqual(self.pns.shootGroups.count, 1)         // One shoot group memorized
                done()
            }
        }
    }

    func testYoutubeVideo() throws {
        helperShootHtml("<video style=\"width: 427px; height: 240px; left: 0px; top: 0px;\" tabindex=\"-1\" class=\"video-stream html5-main-video\" controlslist=\"nodownload\" src=\"https://www.youtube.com/3c46b995-6a5c-44c4-ae60-c62db0d15725\"></video>")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.embed(self.pns.page.url!.absoluteString))
                done()
            }
        }
    }

    func testSingleParagraph() throws {
        helperShootHtml("<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.</p>")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 1)
    }

    func testMultipleParagraphs() throws {
        helperShootHtml("<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.<br></p><p>However, it is worth noting the significant advancements that have been made within the existing creative tooling structures. Integrating coll</p>")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 1)
    }

    func testSingleParagraphWithLink() throws {
        helperShootHtml("Basic HTML familiarity, as covered in <a href=\"/en-US/docs/Learn/HTML/Introduction_to_HTML/Getting_started\">Getting started with HTML</a>")

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
    }

        // Due to the second paragraph only containing whitespace
        // We should expect only 2 "addToNote" events
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 1)
    }

    func testSingleParagraphEndingWithSingleLineBreak() throws {
        helperShootHtml("<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.<br></p>\n")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 1)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 1)
    }

    func testMultipleParagraphsWithLineBreaks() throws {
        helperShootHtml("<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.<br></p>\n          <p>However, it is worth noting the significant advancements that have been made within the existing creative tooling structures. Integrating coll</p>")

        // Validate shoot
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 2)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                XCTAssertEqual(quoteKinds[1], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 2)
    }

    func testFilterEmptyLines() throws {
        let html = "<p>paragraph1<br></p>\n    \n      <p>paragraph3</p>"
        helperShootHtml(html)

        // When splitting paragraphs it should produce an array of 3 items.
        let nonFilteredParagarphs = html.split(separator: "\n")
        XCTAssertEqual(nonFilteredParagarphs.count, 3)

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 2)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                XCTAssertEqual(quoteKinds[1], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }

        // Due to the second paragraph only containing whitespace
        // We should expect only 2 "addToNote" events
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 2)
    }

    func testList() throws {
        helperShootHtml("<div class=\"list-wrapper\"><ol>\n  <li>First item</li>\n  <li>Second item</li>\n  <li>Third item</li>\n  <li>Fourth item</li>  \n</ol>\n</div>")

        // Add shoot to note
        waitUntil(timeout: .seconds(5)) { done in
            self.pns.addShootToNote(noteTitle: self.testPage!.activeNote).then { quoteKinds in
                XCTAssertEqual(quoteKinds.count, 4)
                XCTAssertEqual(quoteKinds[0], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                XCTAssertEqual(quoteKinds[1], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                XCTAssertEqual(quoteKinds[2], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                XCTAssertEqual(quoteKinds[3], BeamCore.ElementKind.quote(1, self.pns.page.title, self.pns.page.url!.absoluteString))
                done()
            }
        }

        // Due to the second paragraph only containing whitespace
        // We should expect only 2 "addToNote" events
        let page = self.testPage!
        let addToNoteEvents = page.events.filter({ $0.contains("addToNote") })
        XCTAssertEqual(addToNoteEvents.count, 4)
    }
}
