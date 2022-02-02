import XCTest
@testable import Beam

class DownloadArtifactTests: XCTestCase {

    private var artifact: DownloadArtifact!
    private var downloadDescription: DownloadDescription!
    private var testDirectory: TestDirectory!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        testDirectory = try TestDirectory.makeTestDirectory(prefixed: "DownloadArtifactTests")
        try createTestDirectories()
        writeTemporaryDownloadFile()
        downloadDescription = try makeDownloadDescription()
    }

    override func tearDownWithError() throws {
        try testDirectory.delete()
    }

    func testCreateDownloadDocument() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)

        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not written to disk")
    }

    func testSaveResumeData() throws {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)
        let data = Data("wesh".utf8)
        artifact.resumeData = data

        let downloadDocumentURL = testDirectory.url
            .appendingPathComponent("dest", isDirectory: true)
            .appendingPathComponent("download.txt.beamdownload")

        let wrapper = try FileWrapper(url: downloadDocumentURL)
        let downloadDocument = try BeamDownloadDocument(fileWrapper: wrapper)

        XCTAssertEqual(downloadDocument.resumeData, data)
    }

    func testComplete() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)
        artifact.complete()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/temp/download.txt")), "Download file is still in temporary directory")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document is still in destination directory")
        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Download file is missing from destination directory")
    }

    func testPreventFilenameCollision() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)

        // Add a similarly named file to destination directory before completing a download with the same filename
        fileManager.createFile(atPath: testDirectory.path.appending("/dest/download.txt"), contents: nil)

        artifact.complete()

        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")))
        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download-2.txt")), "Download file was not renamed before being copied to destination directory")
    }

    func testArtifactURL() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)

        XCTAssertEqual(artifact.artifactURL.path, "\(testDirectory.path)/dest/download.txt.beamdownload")
    }

    func testArtifactURLAfterCompletion() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)
        artifact.complete()

        XCTAssertEqual(artifact.artifactURL.path, "\(testDirectory.path)/dest/download.txt")
    }

    func testFilename() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)

        XCTAssertEqual(artifact.filename, "download.txt")
        XCTAssertEqual(artifact.fileExtension, "txt")
    }

    func testRestoreFromDownloadDocumentThenComplete() throws {
        // Write download document to disk
        let downloadDocumentURL = testDirectory.url
            .appendingPathComponent("dest", isDirectory: true)
            .appendingPathComponent("download.txt.beamdownload")

        let downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)
        downloadDocument.fileURL = downloadDocumentURL

        fileManager.createFile(atPath: downloadDocumentURL.path, contents: nil)

        artifact = try DownloadArtifact(downloadDocument: downloadDocument)
        artifact.complete()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/temp/download.txt")), "Download file is still in temporary directory")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document is still in destination directory")
        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Download file is missing from destination directory")
    }

    func testRestoreFromDownloadDocumentWithMissingFileURL() throws {
        let downloadDocumentURL = testDirectory.url
            .appendingPathComponent("dest", isDirectory: true)
            .appendingPathComponent("download.txt.beamdownload")

        let downloadDocument = BeamDownloadDocument(downloadDescription: downloadDescription)
        fileManager.createFile(atPath: downloadDocumentURL.path, contents: nil)

        XCTAssertThrowsError(try DownloadArtifact(downloadDocument: downloadDocument))
    }

    func testDeleteArtifact() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)

        artifact.deleteFromDisk()

        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/temp/download.txt")), "Temporary download file was not deleted from disk")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt.beamdownload")), "Download document was not deleted from disk")
        XCTAssertFalse(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Download file was moved to destination directory")
    }

    func testDeleteArtifactAfterCompletion() {
        artifact = DownloadArtifact(downloadDescription: downloadDescription)
        artifact.complete()

        artifact.deleteFromDisk()

        XCTAssertTrue(fileManager.fileExists(atPath: testDirectory.path.appending("/dest/download.txt")), "Download file was deleted from disk")
    }

    // MARK: - Helpers

    /// Creates directories at `[[testDirectory]]/temp/` and `[[testDirectory]]/dest/`.
    private func createTestDirectories() throws {
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

