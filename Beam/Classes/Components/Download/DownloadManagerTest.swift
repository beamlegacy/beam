import XCTest
@testable import Beam

import Foundation
import Combine

/**
 This is derived from FavIcon's download test code
 */
class DownloadManagerTest: XCTestCase {

    var scope: Set<AnyCancellable> = []

    func testDownloadText() {
        let result = performDownload(url: "https://apple.com")

        XCTAssertNotNil(result)

        if case .text(let value, let mimeType, _) = result! {
            XCTAssertEqual("text/html", mimeType)
            XCTAssertTrue(value.count > 0)
        } else {
            XCTFail("expected text response")
        }
    }

    func testDownloadTextAndImage() {
        let results = performDownloads(urls: ["https://apple.com", "https://apple.com/favicon.ico"])

        XCTAssertNotNil(results)

        if case .text(let value, let mimeType, _) = results![0] {
            XCTAssertEqual("text/html", mimeType)
            XCTAssertTrue(value.count > 0)
        } else {
            XCTFail("expected text response for first result")
        }

        if case .binary(let data, let mimeType, _) = results![1] {
            XCTAssertEqual("image/x-icon", mimeType)
            XCTAssertTrue(data.count > 0)
        } else {
            XCTFail("expected binary response for second result")
        }
    }

    func testDownloadImage() {
        let result = performDownload(url: "https://google.com/favicon.ico")

        XCTAssertNotNil(result)

        if case .binary(let data, let mimeType, _) = result! {
            XCTAssertEqual("image/x-icon", mimeType)
            XCTAssertTrue(data.count > 0)
        } else {
            XCTFail("expected binary response")
        }
    }

    // Disabled as failing due to network conditions/availability/timeout
    // See https://linear.app/beamapp/issue/BE-1039/file-download-test-fails
    func notestFileDownload() {

        let fileManager = FileManager.default
        let tempURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let timeout: TimeInterval = 45.0

        let downloadManager = BeamDownloadManager()
        let urlToDownload = URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols.dmg")!
        XCTAssertTrue(downloadManager.downloads.isEmpty)
        downloadManager.downloadFile(at: urlToDownload, headers: [:], destinationFoldedURL: tempURL)

        let exp = expectation(description: "downloads \(urlToDownload)")

        XCTAssertFalse(downloadManager.downloads.isEmpty)
        if let download = downloadManager.downloads.first {
            XCTAssertTrue(download.downloadURL == urlToDownload)

            download
                .downloadTask?
                .publisher(for: \.state)
                .receive(on: RunLoop.main)
                .sink { state in
                    if state == .completed {
                        let fileExists = fileManager.fileExists(atPath: download.fileSystemURL.path)
                        XCTAssertTrue(fileExists)
                        exp.fulfill()
                        self.scope.removeAll()
                        try? fileManager.removeItem(at: download.fileSystemURL)
                    }
                }
                .store(in: &scope)
        } else {
            XCTFail("expected a download in the download array")
        }
        wait(for: [exp], timeout: timeout)

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
