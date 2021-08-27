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

    func testImageSrcSet() throws {
        let html = """
            <img srcset="https://cdn.vox-cdn.com/thumbor/fkUSjhcz8i5Fc7BaSKlAeQK5sII=/0x0:2040x1360/320x213/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 320w, https://cdn.vox-cdn.com/thumbor/Z08vUctDdB7hR22UHQ134sPSU38=/0x0:2040x1360/620x413/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 620w, https://cdn.vox-cdn.com/thumbor/vg6dXHVGRUgfW0LzAOnqIYRkkqs=/0x0:2040x1360/920x613/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 920w, https://cdn.vox-cdn.com/thumbor/z_I2AchFEUP_m29s9pAmwVU3e10=/0x0:2040x1360/1220x813/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1220w, https://cdn.vox-cdn.com/thumbor/vJ5jXL0n4PDWRyqZArrxgp02cU8=/0x0:2040x1360/1520x1013/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1520w, https://cdn.vox-cdn.com/thumbor/9xQkpT5PEHjgPykg92aW9lcssYE=/0x0:2040x1360/1820x1213/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 1820w, https://cdn.vox-cdn.com/thumbor/NTw9Gu8yVby6PYkP9EXPVSxa9U0=/0x0:2040x1360/2120x1413/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 2120w, https://cdn.vox-cdn.com/thumbor/rM2KvNsiMD7kEpVqn8aFQJjc574=/0x0:2040x1360/2420x1613/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg 2420w" sizes="(min-width: 1221px) 846px, (min-width: 880px) calc(100vw - 334px), 100vw" alt="" data-upload-width="2040" src="https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg">
            """
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


                XCTAssertEqual(downloadManager?.events[0], "downloaded https://cdn.vox-cdn.com/thumbor/lf-bcEeXrJtxojlBOxneFrJItKQ=/0x0:2040x1360/1200x800/filters:focal(857x517:1183x843)/cdn.vox-cdn.com/uploads/chorus_image/image/69769623/acastro_201210_1777_gmail_0001.0.jpg with headers [\"Referer\": \"https://webpage.com\"]")
                let fileStorage = self.page.fileStorage as? FileStorageMock
                XCTAssertEqual(fileStorage?.events.count, 1)
                XCTAssertEqual(fileStorage?.events[0], "inserted acastro_201210_1777_gmail_0001.0.jpg with id 5289df737df57326fcdd22597afb1fac of image/png for 3 bytes")
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
