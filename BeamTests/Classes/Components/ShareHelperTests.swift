//
//  ShareHelperTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/04/2022.
//

import XCTest
@testable import Beam

class ShareHelperTests: XCTestCase {

    private var sut: ShareHelper!
    private var htmlNoteAdatper: HtmlNoteAdapter!
    private let baseURL = URL(string: "http://sharehelpertests.com")!
    private let timeout: TimeInterval = 2

    override func setUp() {
        htmlNoteAdatper = HtmlNoteAdapter(baseURL, nil, nil)
    }

    private func buildExpectedTwitterURL(with text: String) -> String {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let encodedURL = baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return "https://twitter.com/intent/tweet?text=\(encodedText)&url=\(encodedURL)&via=getonbeam"
    }

    func testShareHtmlWithSingleTextToTwitter() async {
        let text = "one line of text"
        let html = "<p>\(text)</p>"
        var receivedURL: URL?
        let expectation = self.expectation(description: "receive_url")
        let sut = ShareHelper(baseURL, htmlNoteAdapter: htmlNoteAdatper) { url in
            receivedURL = url
            expectation.fulfill()
        }
        await sut.shareContent(html, originURL: baseURL, service: .twitter)
        await waitForExpectations(timeout: timeout, handler: nil)

        let resultURL = receivedURL?.absoluteString ?? ""
        XCTAssertTrue(resultURL.starts(with: "https://twitter.com/intent/tweet?"))
        XCTAssertTrue(resultURL.contains("via=getonbeam"))
        XCTAssertTrue(resultURL.contains("text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
        XCTAssertTrue(resultURL.contains("url=\(baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
    }

    func testShareHtmlWithLinesOfTextToTwitter() async {
        let text = "one line of text"
        let html = "<div><p>\(text)</p><div>\(text)</div><div>\(text)</div></div>"
        var receivedURL: URL?
        let expectation = self.expectation(description: "receive_url")
        let sut = ShareHelper(baseURL, htmlNoteAdapter: htmlNoteAdatper) { url in
            receivedURL = url
            expectation.fulfill()
        }
        await sut.shareContent(html, originURL: baseURL, service: .twitter)
        await waitForExpectations(timeout: timeout, handler: nil)

        let fullText = [text, text, text].joined(separator: .lineSeparator)
        let resultURL = receivedURL?.absoluteString ?? ""
        XCTAssertTrue(resultURL.starts(with: "https://twitter.com/intent/tweet?"))
        XCTAssertTrue(resultURL.contains("via=getonbeam"))
        XCTAssertTrue(resultURL.contains("text=\(fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
        XCTAssertTrue(resultURL.contains("url=\(baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
    }

    func testShareHtmlWithLinesOfTextToPasteboard() async {
        let pasteboard = NSPasteboard.general
        pasteboard.setString("before", forType: .string)
        let text = "one line of text"
        let html = "<div><p>\(text)</p><div>\(text)</div><div>\(text)</div></div>"
        let sut = ShareHelper(baseURL, htmlNoteAdapter: htmlNoteAdatper) { _ in }
        await sut.shareContent(html, originURL: baseURL, service: .copy)

        let fullText = [text, text, text].joined(separator: .lineSeparator)
        XCTAssertEqual(pasteboard.string(forType: .string), fullText)
    }

    private class MockDownloadManager: BeamDownloadManager {
        var mockData: Data?
        var mockFileName = ""
        override func downloadImage(_ src: URL, pageUrl: URL, completion: @escaping ((Data, String)?) -> Void) {
            if let mockData = mockData {
                completion((mockData, mockFileName))
            } else {
                completion(nil)
            }
        }
    }

    func testShareHtmlWithOneImageToPasteboard() async throws {
        let pasteboard = NSPasteboard.general

        let imgURL = "https://image.com/image.jpg"
        let html = "<img src=\"\(imgURL)\"/>"
        let downloadManager = MockDownloadManager()

        guard let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: nil) else {
            XCTFail("Error creating image")
            return
        }
        let imageData = image.jpegRepresentation
        downloadManager.mockData = imageData
        downloadManager.mockFileName = "image.jpg"
        let _ = try BeamFileDBManager.shared?.insert(name: "image.jpg", data: imageData, type: "image/jpeg")

        htmlNoteAdatper = HtmlNoteAdapter(baseURL, downloadManager, BeamFileDBManager.shared)

        let sut = ShareHelper(baseURL, htmlNoteAdapter: htmlNoteAdatper) { _ in }
        await sut.shareContent(html, originURL: baseURL, service: .copy)

        let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)
        XCTAssertEqual(objects?.count, 1)
        XCTAssertTrue(objects?.first is NSImage)
        XCTAssertNil(pasteboard.string(forType: .string))
    }


}
