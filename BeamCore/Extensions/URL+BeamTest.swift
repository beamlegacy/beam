//
//  URL+BeamTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class URLBeamTest: XCTestCase {
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
            "https://www.youtube.com/watch?v=C0DPdy98e4c",
            "https://youtube.com/watch?v=C0DPdy98e4c",
            "https://youtu.be/q0mljE9K-gY"
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertNotNil(url.embed, "failed: \(string)")
        }
    }

    func testYouTubeWatchURL_failure() throws {
        let strings = [
            "www.youtube-nocookie.com/embed/up_lNV-yoK4?rel=0",
            "www.youtube.com/watch?v=C0DPdy98e4c",
            "youtube.com/watch?v=C0DPdy98e4c",
            "youtu.be/C0DPdy98e4c",
            "http://youtube.com/vi/dQw4w9WgXcQ?feature=youtube_gdata_player",
            "http://youtube.com/?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://youtube.com/watch?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://www.youtube.com/oembed?url=http%3A//www.youtube.com/watch?v%3D-wtIMTCHWuI&format=json",
            "https://www.youtube.com/attribution_link?a=8g8kPrPIi-ecwIsS&u=/watch%3Fv%3DyZv2daTWRZU%26feature%3Dem-uploademail",
            "http://www.youtube.com/attribution_link?a=JdfC0C9V6ZI&u=%2Fwatch%3Fv%3DEhxJLojIE_o%26feature%3Dshare"
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertNil(url.embed, "failed: \(string)")
        }
    }

    func testYouTubeWatchURL_extractYouTubeId() throws {
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
            "https://www.youtube.com/watch?v=C0DPdy98e4c",
            "https://youtube.com/watch?v=C0DPdy98e4c",
            "https://youtu.be/q0mljE9K-gY",
            "www.youtube-nocookie.com/embed/up_lNV-yoK4?rel=0",
            "www.youtube.com/watch?v=C0DPdy98e4c",
            "youtube.com/watch?v=C0DPdy98e4c",
            "youtu.be/C0DPdy98e4c"
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertNotNil(url.extractYouTubeId(), "failed: \(string)")
        }
    }

    func testYouTubeWatchURL_extractYouTubeId_failure() throws {
        let strings = [
            "http://youtube.com/vi/dQw4w9WgXcQ?feature=youtube_gdata_player",
            "http://youtube.com/?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://youtube.com/watch?vi=dQw4w9WgXcQ&feature=youtube_gdata_player",
            "http://www.youtube.com/oembed?url=http%3A//www.youtube.com/watch?v%3D-wtIMTCHWuI&format=json",
            "https://www.youtube.com/attribution_link?a=8g8kPrPIi-ecwIsS&u=/watch%3Fv%3DyZv2daTWRZU%26feature%3Dem-uploademail",
            "http://www.youtube.com/attribution_link?a=JdfC0C9V6ZI&u=%2Fwatch%3Fv%3DEhxJLojIE_o%26feature%3Dshare"
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertNil(url.extractYouTubeId(), "failed: \(string)")
        }
    }
}
