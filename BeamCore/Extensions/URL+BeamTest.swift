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
        let string = "https://www.youtube.com/watch?v=ZnuwB35GYMY"
        let url = URL(string: string)!
        if let embed = url.embed {
            XCTAssertEqual(embed.absoluteString, "https://www.youtube.com/embed/ZnuwB35GYMY")
        } else {
            XCTAssert(false)
        }
    }

    func testYouTubeEmbedURL() throws {
        let string = "https://www.youtube.com/embed/ZnuwB35GYMY"
        let url = URL(string: string)!
        if let embed = url.embed {
            XCTAssertEqual(embed.absoluteString, "https://www.youtube.com/embed/ZnuwB35GYMY")
        } else {
            XCTAssert(false)
        }
    }
}
