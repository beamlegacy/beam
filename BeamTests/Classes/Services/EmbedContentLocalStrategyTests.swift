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
    func testYouTubeWatchToEmbedURL() throws {
        let url = "https://www.youtube.com/watch?v=iCtffPv9yKY"
        XCTAssertEqual(embed(url), "https://www.youtube.com/embed/iCtffPv9yKY")
    }

    func testYouTubeWatchShortToEmbedURL() throws {
        let url = "https://youtu.be/iCtffPv9yKY"
        XCTAssertEqual(embed(url), "https://www.youtube.com/embed/iCtffPv9yKY")
    }

    func testYouTubeWatchURL() throws {
        let strings = [
            "http://www.youtube.com/watch?v=peFZbP64dsU",
            "http://www.youtube.com/watch?v=cKZDdG9FTKY&feature=channel",
            "http://youtube.com/v/dQw4w9WgXcQ?feature=youtube_gdata_player",
            "http://youtube.com/?v=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://youtu.be/6dwqZw0j_jY",
            "http://youtu.be/dQw4w9WgXcQ?feature=youtube_gdata_playe",
            "http://www.youtube.com/user/Scobleizer#p/u/1/1p3vcRhsYGo?rel=0",
            "http://www.youtube.com/user/SilkRoadTheatre#p/a/u/2/6dwqZw0j_jY",
            "http://www.youtube.com/watch?v=-wtIMTCHWuI",
            "http://www.youtube.com/v/-wtIMTCHWuI?version=3&autohide=1",
            "http://youtu.be/-wtIMTCHWuI",
            "https://youtu.be/uJ2PZaO1N5E",
            "https://www.youtube.com/embed/M7lc1UVf-VE",
            "https://www.youtube.com/embed/ZnuwB35GYMY",
            "https://www.youtube.com/embed/q0mljE9K-gY",
            "www.youtube-nocookie.com/embed/up_lNV-yoK4?rel=0",
            "www.youtube.com/watch?v=C0DPdy98e4c",
            "youtube.com/watch?v=C0DPdy98e4c",
            "youtu.be/C0DPdy98e4c",
            "https://www.youtube.com/watch?v=C0DPdy98e4c",
            "https://youtube.com/watch?v=C0DPdy98e4c",
            "https://youtu.be/q0mljE9K-gY",
            "https://youtu.be/iCtffPv9yKY",
            "https://www.youtube.com/watch?v=iCtffPv9yKY",
            "https://www.youtube.com/embed/iCtffPv9yKY"
        ]

        for string in strings {
            let result = embed(string)
            XCTAssertNotNil(result, "failed: \(string)")
            if let id = result?.split(separator: "/").last {
                XCTAssertEqual(result, "https://www.youtube.com/embed/\(id)")
            } else {
                XCTFail("failed to get correct youtube embed url")
            }
        }
    }

    func testYouTubeWatchURL_failure() throws {
        let strings = [
            "http://youtube.com/vi/dQw4w9WgXcQ?feature=youtube_gdata_player",
            "http://youtube.com/?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://youtube.com/watch?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://www.youtube.com/oembed?url=http%3A//www.youtube.com/watch?v%3D-wtIMTCHWuI&format=json",
            "https://www.youtube.com/attribution_link?a=8g8kPrPIi-ecwIsS&u=/watch%3Fv%3DyZv2daTWRZU%26feature%3Dem-uploademail",
            "http://www.youtube.com/attribution_link?a=JdfC0C9V6ZI&u=%2Fwatch%3Fv%3DEhxJLojIE_o%26feature%3Dshare"
        ]

        for string in strings {
            XCTAssertNil(embed(string), "failed: \(string)")
        }
    }
}
