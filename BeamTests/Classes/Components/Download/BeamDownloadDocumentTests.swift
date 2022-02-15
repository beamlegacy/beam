import XCTest
@testable import Beam

class BeamDownloadDocumentTests: XCTestCase {

    private var downloadDescription: DownloadDescription!
    private var testDirectory: TestDirectory!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        testDirectory = try TestDirectory.makeTestDirectory(prefixed: "BeamDownloadDocumentTests")
        try createTestSubdirectory()
        downloadDescription = try makeDownloadDescription()
    }

    override func tearDownWithError() throws {
        try testDirectory.delete()
    }

    func testSave() {
        let url = downloadDescription.destinationDirectoryURL.appendingPathComponent("download.txt.beamdownload")
        let downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)

        let expectation = XCTestExpectation()
        downloadDocument.save(to: url, ofType: BeamDownloadDocument.documentTypeName, for: .saveOperation) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(fileManager.fileExists(atPath: url.path), "Download document was not written to disk")
    }

    func testDecode() throws {
        // Write document to disk
        let url = downloadDescription.destinationDirectoryURL.appendingPathComponent("download.txt.beamdownload")
        let data = Data("djobidjoba".utf8)
        let downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)
        downloadDocument.resumeData = data
        let expectation = XCTestExpectation()
        downloadDocument.save(to: url, ofType: BeamDownloadDocument.documentTypeName, for: .saveOperation) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        // Decode document on disk
        let wrapper = try XCTUnwrap(FileWrapper(url: url, options: .immediate))
        let decodedDownloadDocument = try BeamDownloadDocument(fileWrapper: wrapper)

        XCTAssertEqual(decodedDownloadDocument.downloadDescription?.downloadId, downloadDescription.downloadId)
        XCTAssertEqual(decodedDownloadDocument.resumeData, data)
    }

    // MARK: - Helpers

    /// Creates directories at `[[testDirectory]]/temp/` and `[[testDirectory]]/dest/`.
    private func createTestSubdirectory() throws {
        let destinationDirectoryURL = testDirectory.url.appendingPathComponent("dest", isDirectory: true)

        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
    }

    private func makeDownloadDescription() throws -> DownloadDescription {
        let filename = "download.txt"
        let temporaryDirectoryURL = testDirectory.url.appendingPathComponent("temp", isDirectory: true)
        let destinationDirectoryURL = testDirectory.url.appendingPathComponent("dest", isDirectory: true)
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent(filename)

        return DownloadDescription(
            downloadId: UUID(),
            originalRequestURL: URL(string: "https://djobidjo.ba/dl"),
            suggestedFilename: filename,
            temporaryFileURL: temporaryFileURL,
            destinationDirectoryURL: destinationDirectoryURL
        )
    }

}
