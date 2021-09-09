import XCTest
import Foundation
@testable import BeamCore

class BeamTextLinksTests: XCTestCase {
    func testLink1() {
        let id = UUID()
        let text = BeamText(text: "test", attributes: [.internalLink(id)])

        XCTAssertTrue(text.hasLinkToNote(id: id))
        let links = text.internalLinks
        XCTAssertEqual(links.count, 1)
        XCTAssertTrue(links.contains(id))
    }

    func testLink2() {
        let id = UUID()
        var text = BeamText(text: "test hop bleh")
        text.addAttributes([.internalLink(id)], to: 5..<9)
        XCTAssertTrue(text.hasLinkToNote(id: id))
        let links = text.internalLinks
        XCTAssertTrue(links.count == 1)
        XCTAssertTrue(links.contains(id))
    }

    func testLink3() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        var text = BeamText(text: "test hop bleh")
        text.addAttributes([.internalLink(id1)], to: 5..<9)
        text.addAttributes([.internalLink(id2)], to: 10..<15)

        let links = text.internalLinks
        XCTAssertEqual(links.count, 2)
        XCTAssertTrue(links.contains(id1))
        XCTAssertTrue(links.contains(id2))
        XCTAssertTrue(!links.contains(id3))
        XCTAssertTrue(text.hasLinkToNote(id: id1))
        XCTAssertTrue(text.hasLinkToNote(id: id2))
        XCTAssertFalse(text.hasLinkToNote(id: id3))
    }

    func testNoteSourceEligibleLinks() {
        let rawContent = "abc http://www.ping.com pong efg"
        var text = BeamText(text: rawContent)
        text.addAttributes([.link("http://www.ping.com")], to: 4..<23)
        text.addAttributes([.link("http://www.pong.fr")], to: 24..<28)
        let eligibleRanges = text.noteSourceEligibleLinkRanges
        if eligibleRanges.count != 1 {
            XCTFail("http://www.ping.com should be an eligible url")
        } else {
            let eligibleRange = eligibleRanges[0]
            XCTAssertEqual(eligibleRange.string, "http://www.ping.com")
        }
    }
}
