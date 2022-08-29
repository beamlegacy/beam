//
//  ShareHelperTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/04/2022.
//

import XCTest
import BeamCore
@testable import Beam

class ShareHelperTests: XCTestCase {
    private let baseURL = URL(string: "http://sharehelpertests.com")!
    private let timeout: TimeInterval = 2

    private func buildExpectedTwitterURL(with text: String) -> String {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let encodedURL = baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return "https://twitter.com/intent/tweet?text=\(encodedText)&url=\(encodedURL)&via=getonbeam"
    }

    func testShareHtmlWithSingleTextToTwitter() async {
        let text = "one line of text"
        let content = [BeamElement(text)]
        var receivedURL: URL?
        let expectation = self.expectation(description: "receive_url")
        let sut = ShareHelper(baseURL) { url in
            receivedURL = url
            expectation.fulfill()
        }
        await sut.shareContent(content, originURL: baseURL, service: .twitter)
        await waitForExpectations(timeout: timeout, handler: nil)

        let resultURL = receivedURL?.absoluteString ?? ""
        XCTAssertTrue(resultURL.starts(with: "https://twitter.com/intent/tweet?"))
        XCTAssertTrue(resultURL.contains("via=getonbeam"))
        XCTAssertTrue(resultURL.contains("text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
        XCTAssertTrue(resultURL.contains("url=\(baseURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<failToEncode>")"))
    }

    func testShareHtmlWithLinesOfTextToTwitter() async {
        let text = "one line of text"
        let content = [
            BeamElement(text),
            BeamElement(text),
            BeamElement(text)
        ]
        var receivedURL: URL?
        let expectation = self.expectation(description: "receive_url")
        let sut = ShareHelper(baseURL) { url in
            receivedURL = url
            expectation.fulfill()
        }
        await sut.shareContent(content, originURL: baseURL, service: .twitter)
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
        let content = [
            BeamElement(text),
            BeamElement(text),
            BeamElement(text)
        ]
        let sut = ShareHelper(baseURL) { _ in }
        await sut.shareContent(content, originURL: baseURL, service: .copy)

        let fullText = [text, text, text].joined(separator: .lineSeparator)
        XCTAssertEqual(pasteboard.string(forType: .string), fullText)
    }

    private class MockDownloadManager: BeamDownloadManager {
        var mockData: Data?
        var mockFileName = ""
        override func downloadImage(_ src: URL, pageUrl: URL, completion: @escaping (DownloadManagerResult?) -> Void) {
            if let mockData = mockData {
                completion(.binary(data: mockData, mimeType: "", actualURL: src))
            } else {
                completion(nil)
            }
        }
    }

    func testShareHtmlWithOneImageToPasteboard() async throws {
        let pasteboard = NSPasteboard.general
        let downloadManager = MockDownloadManager()

        guard let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: nil),
              let imageData = image.jpegRepresentation
        else {
            XCTFail("Error creating image")
            return
        }

        downloadManager.mockData = imageData
        downloadManager.mockFileName = "image.jpg"
        guard let fileID = try BeamFileDBManager.shared?.insert(name: "image.jpg", data: imageData, type: "image/jpeg") else {
            XCTFail("fileID is required for test to pass")
            return
        }

        let imageElement = BeamElement()
        imageElement.kind = .image(
            fileID,
            origin: .init(),
            displayInfos: .init()
        )

        let sut = ShareHelper(baseURL) { _ in }
        await sut.shareContent([imageElement], originURL: baseURL, service: .copy)

        let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)
        XCTAssertEqual(objects?.count, 1)
        XCTAssertTrue(objects?.first is NSImage)
        XCTAssertNil(pasteboard.string(forType: .string))
    }


}
