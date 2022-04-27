//
//  WebNoteControllerTitleTests.swift
//  BeamTests
//
//  Created by Stef Kors on 26/04/2022.
//

import XCTest

@testable import Beam
@testable import BeamCore

class WebNoteControllerTitleTests: XCTestCase {
    class MockSocialTitleFetcher: SocialTitleFetcher {
        var mockTitle: String?

        func getMockTitle(_ url: URL) throws -> SocialTitle? {
            SocialTitle(url: url, title: "\(mockTitle ?? "")")
        }
        override func fetch(for url: URL, completion: @escaping (Result<SocialTitle?, SocialTitleFetcherError>) -> Void) {
            let result = Result(catching: {
                try getMockTitle(url)
            }).mapError({ _ in
                SocialTitleFetcherError.failedRequest
            })
            completion(result)
        }
    }

    var words = WordsFile()
    var note = BeamNote(title: "Sample note")

    override func setUpWithError() throws {
        note = BeamNote(title: "Sample note")
        SocialTitleFetcher.shared = MockSocialTitleFetcher()
    }

    func testTitlePercentEncoding() async throws {
        let controller = WebNoteController(note: note)
        let mockFetcher = MockSocialTitleFetcher()
        mockFetcher.mockTitle = "Web%20%26%20Notes"
        SocialTitleFetcher.shared = mockFetcher
        let sourceLink = URL(string: "https://www.hellobeam.com")!
        let paragraph1 = BeamElement("example content with a lot of words")
        ///
        /// 1. AddContent
        /// SourceLink
        /// - Paragraph1
        await controller.addContent(content: [paragraph1], with: sourceLink, reason: .pointandshoot)
        ///
        /// Expect the note to look like:
        /// SourceLink (without percent encoding)
        /// - Paragraph1
        XCTAssertEqual(controller.note?.children.count, 1)
        if let firstChild = controller.note?.children.first {
            XCTAssertEqual(firstChild.text.text, "Web & Notes")
            XCTAssertNotEqual(firstChild.text.text, "Web%20%26%20Notes")
            XCTAssertEqual(firstChild.children, [paragraph1])
        }
    }
}
