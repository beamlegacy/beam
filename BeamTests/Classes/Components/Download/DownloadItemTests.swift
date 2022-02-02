import XCTest
import Combine
@testable import Beam

class DownloadItemTests: XCTestCase {

    private var downloadItem: DownloadItem!
    private var testDirectory: TestDirectory!
    private var downloadProxyMock: DownloadProxyMock!
    private var cancellables: Set<AnyCancellable>!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        testDirectory = try TestDirectory.makeTestDirectory(prefixed: "DownloadItemTests")
        try createTestSubdirectories()
        downloadProxyMock = DownloadProxyMock()
        cancellables = []
    }

    override func tearDownWithError() throws {
        try testDirectory.delete()
    }

    func testInitialRunningState() {
        downloadItem = makeDownloadItem()

        XCTAssertEqual(downloadItem.state, .running)
    }

    func testCancel() {
        downloadItem = makeDownloadItem()

        downloadItem.cancel()

        XCTAssertEqual(downloadItem.state, .suspended)
        XCTAssertEqual(downloadProxyMock.cancelCallsCount, 1)
    }

    func testSuspendOnError() {
        downloadItem = makeDownloadItem()

        downloadProxyMock.triggerDelegateDidFail(resumeData: nil)

        XCTAssertEqual(downloadItem.state, .suspended)
    }

    func testErrorMessage() {
        downloadItem = makeDownloadItem()

        downloadProxyMock.triggerDelegateDidFail(resumeData: nil)

        XCTAssertNotNil(downloadItem.errorMessage)
    }

    func testCompleteOnFinish() {
        downloadItem = makeDownloadItem()

        downloadProxyMock.triggerDelegateDidFinish()

        XCTAssertEqual(downloadItem.state, .completed)
    }

    func testReturnTemporaryURLToDelegate() {
        downloadItem = makeDownloadItem()

        triggerDelegateDecideDestination(suggestedFilename: "download.txt")

        XCTAssertEqual(downloadProxyMock.destinationURL?.path, testDirectory.path.appending("/temp/download.txt"), "Didn't return a destination in the temporary directory to the delegate")
    }

    func testPreventFilenameCollisionsInTemporaryDirectory() {
        downloadItem = makeDownloadItem()
        writeTemporaryDownloadFile()

        triggerDelegateDecideDestination(suggestedFilename: "download.txt")

        XCTAssertEqual(downloadProxyMock.destinationURL?.path, testDirectory.path.appending("/temp/download-2.txt"), "Didn't return an available file URL to the delegate")
    }

    func testWriteDownloadFileToDisk() {
        downloadItem = makeDownloadItem()

        triggerDelegateDecideDestination(suggestedFilename: "download.txt")

        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not created")
    }

    func testMoveDownloadFileOnCompletion() {
        downloadItem = makeDownloadItem()
        triggerDelegateDecideDestination(suggestedFilename: "download.txt")

        writeTemporaryDownloadFile()
        downloadProxyMock.triggerDelegateDidFinish()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not deleted")
        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Completed download file was not moved to destination directory")
    }

    func testDeleteUncompleteArtifacts() {
        downloadItem = makeDownloadItem()
        triggerDelegateDecideDestination(suggestedFilename: "download.txt")
        writeTemporaryDownloadFile()
        downloadItem.deleteArtifactIfNotCompleted()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/temp/download.txt")), "Temporary download file was not deleted")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not deleted")
    }

    func testKeepCompleteDownloadFile() {
        downloadItem = makeDownloadItem()
        triggerDelegateDecideDestination(suggestedFilename: "download.txt")
        writeTemporaryDownloadFile()
        downloadProxyMock.triggerDelegateDidFinish()

        downloadItem.deleteArtifactIfNotCompleted()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/temp/download.txt")), "Temporary download file was not deleted")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not deleted")
        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Complete download file was deleted")
    }

    func testResumeAfterError() throws {
        downloadItem = makeDownloadItem()
        triggerDelegateDecideDestination()
        let expectedResumeData = Data("wesh".utf8)

        downloadProxyMock.triggerDelegateDidFail(resumeData: expectedResumeData)
        try downloadItem.resume()

        let resumeData = try XCTUnwrap(downloadProxyMock.resumeDownloadCalls.first)
        XCTAssertEqual(resumeData, expectedResumeData, "Resume data received from failure was not reused")
    }

    func testResumeAfterCancelWithResumeData() throws {
        downloadItem = makeDownloadItem()
        triggerDelegateDecideDestination()
        let expectedResumeData = Data("wesh".utf8)
        downloadProxyMock.resumeData = expectedResumeData

        downloadItem.cancel()
        try downloadItem.resume()

        let resumeData = try XCTUnwrap(downloadProxyMock.resumeDownloadCalls.first)
        XCTAssertEqual(resumeData, expectedResumeData, "Resume data received at cancel time was not reused")
    }

    func testResumeAfterCancelWithOriginalRequest() throws {
        downloadItem = makeDownloadItem()
        let expectedURL = URL(string: "https://djobidjo.ba/dl")!
        downloadProxyMock.originalRequest = URLRequest(url: expectedURL)
        triggerDelegateDecideDestination()

        downloadItem.cancel()
        try downloadItem.resume()

        let url = try XCTUnwrap(downloadProxyMock.startDownloadCalls.first?.url)
        XCTAssertEqual(url, expectedURL, "Original request URL received from download proxy was not reused")
    }

    func testRestartAfterCancelWithPreviousSuggestedFileName() throws {
        downloadItem = makeDownloadItem()
        let expectedURL = URL(string: "https://djobidjo.ba/dl")!
        downloadProxyMock.originalRequest = URLRequest(url: expectedURL)
        triggerDelegateDecideDestination(suggestedFilename: "download.txt")

        try downloadItem.restart()
        triggerDelegateDecideDestination(suggestedFilename: "Unknown.txt")

        XCTAssertEqual(downloadProxyMock.destinationURL?.path, testDirectory.path.appending("/temp/download.txt"), "Didn't preserve the original suggested name")
    }

    func testResumeFromResumeDataInDownloadDocument() throws {
        let downloadDescription = makeDownloadDescription()
        let downloadDocument = makeDownloadDocument(downloadDescription: downloadDescription)
        let expectedResumeData = Data("wesh".utf8)
        downloadDocument.resumeData = expectedResumeData

        downloadItem = try makeDownloadItem(downloadDocument: downloadDocument)

        let resumeData = try XCTUnwrap(downloadProxyMock.resumeDownloadCalls.first)
        XCTAssertEqual(resumeData, expectedResumeData, "Resume data in download document was not reused")
    }

    func testResumeFromOriginalRequestInDownloadDocument() throws {
        let downloadDescription = makeDownloadDescription()
        let downloadDocument = makeDownloadDocument(downloadDescription: downloadDescription)
        let expectedURL = URL(string: "https://djobidjo.ba/dl")!

        downloadItem = try makeDownloadItem(downloadDocument: downloadDocument)

        let url = try XCTUnwrap(downloadProxyMock.startDownloadCalls.first?.url)
        XCTAssertEqual(url, expectedURL, "Original request URL in download document was not reused")
    }

    func testResumeFromDownloadDocumentMissingResumeDataAndOriginalRequest() throws {
        let downloadDocument = makeDownloadDocument(downloadDescription: nil)

        try XCTAssertThrowsError(makeDownloadItem(downloadDocument: downloadDocument), "Download document without download description must throw")
    }

    func testPreserveIdentifierWhenResumingFromDownloadDocument() throws {
        let downloadDescription = makeDownloadDescription()
        let downloadDocument = makeDownloadDocument(downloadDescription: downloadDescription)

        downloadItem = try makeDownloadItem(downloadDocument: downloadDocument)

        XCTAssertEqual(downloadItem.id, downloadDescription.downloadId, "Identifiers of the download item and its download description didn't match")
    }

    func testProgressFractionCompleted() {
        downloadItem = makeDownloadItem()

        let expectation = XCTestExpectation()
        var fraction: Double = 0

        downloadItem.$progressFractionCompleted
            .dropFirst()
            .sink {
                fraction = $0
                expectation.fulfill()
            }
            .store(in: &cancellables)

        triggerDelegateDecideDestination()

        downloadProxyMock.progress.totalUnitCount = 100_000_000
        downloadProxyMock.progress.completedUnitCount = 50_000_000

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(fraction, 0.5)
    }

    func testProgressDescriptionWhileDownloading() {
        downloadItem = makeDownloadItem()

        let expectation = XCTestExpectation()
        var description: String? = nil

        downloadItem.$progressDescription
            .dropFirst()
            .sink {
                description = $0
                expectation.fulfill()
            }
            .store(in: &cancellables)

        triggerDelegateDecideDestination()

        downloadProxyMock.progress.totalUnitCount = 100_000_000
        downloadProxyMock.progress.completedUnitCount = 50_000_000

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(description, "50 MB of 100 MB")
    }

    func testProgressDescriptionOnCompletion() {
        downloadItem = makeDownloadItem()

        let expectation = XCTestExpectation()
        var description: String? = nil

        downloadItem.$progressDescription
            .dropFirst()
            .sink {
                description = $0
                expectation.fulfill()
            }
            .store(in: &cancellables)

        triggerDelegateDecideDestination()
        downloadProxyMock.triggerDelegateDidFinish()

        downloadProxyMock.progress.totalUnitCount = 100_000_000
        downloadProxyMock.progress.completedUnitCount = 100_000_000

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(description, "100 MB")
    }

    func testDelegateStatusChanges() throws {
        downloadItem = makeDownloadItem()
        let delegate = DownloadItemDelegateMock()
        downloadItem.delegate = delegate
        downloadProxyMock.resumeData = Data("".utf8)
        triggerDelegateDecideDestination()

        downloadItem.cancel()
        XCTAssertEqual(delegate.state, .suspended)

        try downloadItem.resume()
        XCTAssertEqual(delegate.state, .running)

        downloadProxyMock.triggerDelegateDidFail(resumeData: Data("".utf8))
        XCTAssertEqual(delegate.state, .suspended)

        downloadProxyMock.triggerDelegateDidFinish()
        XCTAssertEqual(delegate.state, .completed)
    }

    // MARK: - Helpers

    private func makeDownloadItem() -> DownloadItem {
        DownloadItem(
            downloadProxy: downloadProxyMock,
            destinationDirectoryURL: testDirectory.url.appendingPathComponent("dest"),
            temporaryDirectoryPath: testDirectory.path.appending("/temp")
        )
    }

    private func makeDownloadItem(downloadDocument: BeamDownloadDocument) throws -> DownloadItem {
        try DownloadItem(downloadProxy: downloadProxyMock, downloadDocument: downloadDocument)
    }

    private func makeDownloadDescription() -> DownloadDescription {
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

    private func makeDownloadDocument(downloadDescription: DownloadDescription?) -> BeamDownloadDocument {
        let downloadDocumentURL = testDirectory.url
            .appendingPathComponent("dest", isDirectory: true)
            .appendingPathComponent("download.txt.beamdownload")

        let downloadDocument: BeamDownloadDocument
        if let downloadDescription = downloadDescription {
            downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)
        } else {
            downloadDocument = BeamDownloadDocument()
        }

        downloadDocument.fileURL = downloadDocumentURL
        return downloadDocument
    }

    private func triggerDelegateDecideDestination(suggestedFilename: String = "download.txt") {
        downloadProxyMock.triggerDelegateDecideDestination(
            destination: testDirectory.url.appendingPathComponent("temp"),
            suggestedFilename: suggestedFilename
        )
    }

    /// Creates directories at `[[testDirectory]]/temp/` and `[[testDirectory]]/dest/`.
    private func createTestSubdirectories() throws {
        let temporaryDirectoryURL = testDirectory.url.appendingPathComponent("temp", isDirectory: true)
        let destinationDirectoryURL = testDirectory.url.appendingPathComponent("dest", isDirectory: true)

        try fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
    }

    /// Writes file at `[[testDirectory]]/temp/download.txt`.
    private func writeTemporaryDownloadFile() {
        let temporaryDirectoryURL = testDirectory.url.appendingPathComponent("temp", isDirectory: true)
        let temporaryFileURL = temporaryDirectoryURL.appendingPathComponent("download.txt")

        fileManager.createFile(atPath: temporaryFileURL.path, contents: nil)
    }


}
