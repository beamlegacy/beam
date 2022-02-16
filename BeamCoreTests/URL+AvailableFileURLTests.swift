import XCTest
@testable import BeamCore

class URLAvailableFileURLTests: XCTestCase {

    private var testDirectory: TestDirectory!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        testDirectory = try TestDirectory.makeTestDirectory(prefixed: "DownloadArtifactTests")
    }

    override func tearDownWithError() throws {
        try testDirectory.delete()
    }

    func testNonExistingFile() {
        let url = testDirectory.url.appendingPathComponent("/gigou.txt")

        XCTAssertEqual(url.availableFileURL(), url, "URL was modified even though there is no file at this location")
    }

    func testExistingFile() {
        fileManager.createFile(atPath: testDirectory.path.appending("/gigou.txt"), contents: nil)

        let url = testDirectory.url.appendingPathComponent("/gigou.txt")
        let expected = testDirectory.url.appendingPathComponent("/gigou-2.txt")
        XCTAssertEqual(url.availableFileURL(), expected, "File was not renamed to `gigou-2.txt`")
    }

    func testMultipleExistingFiles() {
        fileManager.createFile(atPath: testDirectory.path.appending("/gigou.txt"), contents: nil)
        fileManager.createFile(atPath: testDirectory.path.appending("/gigou-2.txt"), contents: nil)

        let url = testDirectory.url.appendingPathComponent("/gigou.txt")
        let expected = testDirectory.url.appendingPathComponent("/gigou-3.txt")
        XCTAssertEqual(url.availableFileURL(), expected, "File was not renamed to `gigou-3.txt`")
    }

    func testExistingFileWithMultipleExtensions() {
        fileManager.createFile(atPath: testDirectory.path.appending("/gigou.wesh.txt"), contents: nil)

        let url = testDirectory.url.appendingPathComponent("/gigou.wesh.txt")
        let expected = testDirectory.url.appendingPathComponent("/gigou-2.wesh.txt")
        XCTAssertEqual(url.availableFileURL(), expected, "File was not renamed to `gigou-2.wesh.txt`")
    }

    func testNonFileURL() {
        let url = URL(string: "https://beamapp.co/some/path")!

        XCTAssertEqual(url.availableFileURL(), url)
    }

}
