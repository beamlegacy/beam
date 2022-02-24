import XCTest
@testable import BeamCore

class HTTPURLResponseRequestsDownloadTests: XCTestCase {

    private let url = URL(string: "#")!

    func testContentTypeForceDownload() {
        // Inspired by https://www.service-public.fr/particuliers/vosdroits/R1976
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Disposition": "inline; filename=\"Wesh.pdf\"",
            "Content-Type": "application/force-download"
        ])

        XCTAssertTrue(response!.requestsDownload)
    }

    func testContentDispositionAttachment() {
        // Inspired by mega.nz
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Disposition": "attachment",
            "Content-Type": "application/octet-stream"
        ])

        XCTAssertTrue(response!.requestsDownload)
    }

    func testContentDispositionInlineWithFilename() {
        // Inspired by https://www.roblox.com/games/4924922222/Brookhaven-RP
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Disposition": "inline; filename=Wesh.dmg",
            "Content-Type": "application/dmg"
        ])

        XCTAssertTrue(response!.requestsDownload)
    }

    func testContentDispositionInline() {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Content-Disposition": "inline"
        ])

        XCTAssertFalse(response!.requestsDownload)
    }

}
