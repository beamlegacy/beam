//
//  EmbedContentAPIStrategyTests.swift
//  BeamTests
//
//  Created by Remi Santos on 04/11/2021.
//

import XCTest

@testable import Beam

class EmbedContentAPIStrategyTests: XCTestCase {

    func testCanEmbed() {
        let st = EmbedContentAPIStrategy()
        let strings = [
            "https://youtube.com/vi/dQw4w9WgXcQ?",
            "https://twitter.com/beamapp",
            "https://instagram.com/p/asdbwef",
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertTrue(st.canBuildEmbeddableContent(for: url))
        }
    }

    func testCannotEmbed() {
        let st = EmbedContentAPIStrategy()
        let strings = [
            "https://beamapp.co/dl/app",
            "https://apple.com/macbook",
            "https://theverge.com/p/asdbwef",
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertFalse(st.canBuildEmbeddableContent(for: url))
        }
    }
}

