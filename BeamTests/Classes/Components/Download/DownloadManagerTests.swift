import XCTest
@testable import Beam

import Foundation
import Combine

/**
 This is derived from FavIcon's download test code
 */
class DownloadManagerTests: XCTestCase {

    var scope: Set<AnyCancellable> = []

    func testDownloadText() {
        let result = performDownload(url: "https://apple.com")

        XCTAssertNotNil(result)

        guard let result = result, case .text(let value, let mimeType, _) = result else {
            XCTFail("expected text response")
            return
        }

        XCTAssertEqual("text/html", mimeType)
        XCTAssertTrue(value.count > 0)
    }

    func testDownloadTextAndImage() {
        let results = performDownloads(urls: ["https://apple.com", "https://apple.com/favicon.ico"])

        XCTAssertNotNil(results)

        if let text = results?.first, case .text(let value, let mimeType, _) = text {
            XCTAssertEqual("text/html", mimeType)
            XCTAssertTrue(value.count > 0)
        } else {
            XCTFail("expected text response for first result")
        }

        if let image = results?[1], case .binary(let data, let mimeType, _) = image {
            XCTAssertEqual("image/x-icon", mimeType)
            XCTAssertTrue(data.count > 0)
        } else {
            XCTFail("expected binary response for second result")
        }
    }

    func testDownloadImage() {
        let result = performDownload(url: "https://google.com/favicon.ico")

        XCTAssertNotNil(result)

        guard let result = result, case .binary(let data, let mimeType, _) = result else {
            XCTFail("expected binary response")
            return
        }

        XCTAssertEqual("image/x-icon", mimeType)
        XCTAssertTrue(data.count > 0)
    }

    private func performDownloads(urls: [String], timeout: TimeInterval = 15.0) -> [DownloadManagerResult]? {
        var actualResults: [DownloadManagerResult]?

        let downloadsCompleted = expectation(description: "download: \(urls)")
        let downloadManager = BeamDownloadManager()
        downloadManager.downloadURLs(urls.map { URL(string: $0)! }, headers: [:]) { results in
            actualResults = results
            downloadsCompleted.fulfill()
        }
        wait(for: [downloadsCompleted], timeout: timeout)

        return actualResults
    }

    private func performDownload(url: String, timeout: TimeInterval = 15.0) -> DownloadManagerResult? {
        var actualResult: DownloadManagerResult?

        let downloadCompleted = expectation(description: "download: \(url)")
        let downloadManager = BeamDownloadManager()
        downloadManager.downloadURL(URL(string: url)!, headers: [:]) { result in
            actualResult = result
            downloadCompleted.fulfill()
        }
        wait(for: [downloadCompleted], timeout: timeout)

        return actualResult
    }
}
