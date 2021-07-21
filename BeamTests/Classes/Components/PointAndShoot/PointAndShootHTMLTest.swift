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

    func testImageRelative() throws {
        let html = "<img src=\"someImage.png\">"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
                let downloadManager = self.page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)
                XCTAssertEqual(downloadManager?.events[0], "downloaded https://webpage.com/someImage.png with headers [\"Referer\": \"https://webpage.com\"]")

                let fileStorage = self.page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                done()
            }
        }
    }

    func testImageExternal() throws {
        let html = "<img src=\"https://i.imgur.com/someImage.png\">"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
                let downloadManager = self.page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)

                XCTAssertEqual(downloadManager?.events[0], "downloaded https://i.imgur.com/someImage.png with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = self.page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                done()
            }
        }
    }

    func testImageAnyScheme() throws {
        let html = "<img alt=\"\" src=\"//i.imgur.com/someImage.png\">"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.image("5289df737df57326fcdd22597afb1fac"))
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
                let downloadManager = self.page.downloadManager as? DownloadManagerMock
                XCTAssertEqual(downloadManager?.events.count, 1)

                XCTAssertEqual(downloadManager?.events[0], "downloaded https://i.imgur.com/someImage.png with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = self.page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted someImage.png with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
                done()
            }
        }
    }

    func testYoutubeVideo() throws {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let html = "<video style=\"width: 427px; height: 240px; left: 0px; top: 0px;\" tabindex=\"-1\" class=\"video-stream html5-main-video\" controlslist=\"nodownload\" src=\"blob:https://www.youtube.com/3151f5a7-5ea5-4148-af51-4daf3e6ed7ee\"></video>"
        let text: [BeamText] = html2Text(url: URL(string: url)!, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, url)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.embed("https://www.youtube.com/embed/dQw4w9WgXcQ"))
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }
    }

    func testYouTubeIframe() throws {
        let html = "<iframe width=\"728\" height=\"410\" src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\" title=\"YouTube video player\" frameborder=\"0\" allow=\"accelerometer; autoplay;clipboard-write;encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.embed("https://www.youtube.com/embed/dQw4w9WgXcQ"))
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }
    }

    func testSingleParagraph() throws {
        let html = "<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.</p>"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.quote(1, self.page.title, self.url.absoluteString))
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }
    }

    func testMultipleParagraphs() throws {
        let html = "<p>We see this further exemplified through tools looking and operating very similarly to how they did at their founding.<br></p><p>However, it is worth noting the significant advancements that have been made within the existing creative tooling structures. Integrating coll</p>"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 2)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.quote(1, self.page.title, self.url.absoluteString))
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }
    }

    func testSingleParagraphWithLink() throws {
        let html = "Basic HTML familiarity, as covered in <a href=\"/en-US/docs/Learn/HTML/Introduction_to_HTML/Getting_started\">Getting started with HTML</a>"
        let text: [BeamText] = html2Text(url: self.url, html: html)

        waitUntil(timeout: .seconds(5)) { done in
            let pendingQuotes = self.pns.text2Quote(text, self.url.absoluteString)
            pendingQuotes.then { quotes in
                XCTAssertEqual(quotes.count, 1)
                if let quote = quotes.first {
                    XCTAssertEqual(quote.kind, ElementKind.quote(1, self.page.title, self.url.absoluteString))
                    done()
                } else {
                    XCTFail("expected quotes to contain 1 item")
                }
            }
        }
    }
}
