//
//  EmbedContentLocalStrategyTests.swift
//  BeamTests
//
//  Created by Remi Santos on 04/11/2021.
//

import XCTest
@testable import Beam

class EmbedContentLocalStrategyTests: XCTestCase {

    func embed(_ urlString: String) -> String? {
        let st = EmbedContentLocalStrategy()
        guard let url = URL(string: urlString) else {
            return nil
        }
        var result: URL?
        st.embeddableContent(for: url) { content, _ in
            result = content?.embedURL
        }
        return result?.absoluteString
    }

    // MARK: Youtube
    func testYouTubeEmbed() throws {
        let url = "https://www.youtube.com/embed/M7lc1UVf-VE?start=61"
        XCTAssertEqual(embed(url), "https://www.youtube.com/embed/M7lc1UVf-VE?start=61")
    }
}
