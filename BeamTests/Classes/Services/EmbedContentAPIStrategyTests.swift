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
            "https://twitter.com/getonbeam/status/1461351986209562631",
            "https://open.spotify.com/artist/6sFIWsNpZYqfjUpaCgueju?si=9j3YkSZsSDilNJmgI8WOow",
            "https://open.spotify.com/track/20I6sIOMTCkB6w7ryavxtO?si=7163454bfae34756",
            "https://open.spotify.com/playlist/4ihev57yAYpjLYhCgzicjy",
            "https://open.spotify.com/show/71mvGXupfKcmO6jlmOJQTP?si=44700a9a7560484d",
            "https://www.youtube.com/watch?v=lYHzdqGR9-U",
            "https://vimeo.com/ondemand/theletterroom/515769553?autoplay=1",
            "https://vimeo.com/groups/ConstructionPaper/videos/51136154",
            "https://vimeo.com/channels/staffpicks/342870",
            "https://vimeo.com/album/5376202/video/286898202",
            "https://vimeo.com/286898202",
            "https://www.instagram.com/p/CQrBE1RDCKf",
            "https://www.twitch.tv/cocoatype/video/1221611733",
            "https://public.beamapp.co/jeromebeam/note/c71239ba-9d75-433b-a776-f75d2640e260/Baudrillard",
            "https://sketchfab.com/models/dGUrytaktlDeNudCEGKk31oTJY",
            "http://www.slideshare.net/haraldf/business-quotes-for-2011",
            "https://www.deviantart.com/fi2-shift/art/Apple-Metal-107692353",
            "https://www.ted.com/talks/astro_teller_the_unexpected_benefit_of_celebrating_failure",
            "https://www.flickr.com/photos/hotelcurly/21982802134/in/photolist-zuxBcU-zUC8zW-qx6Jkg-quT1TR-9cwzji-8d6UnM-e1RwnD-FKnLR-5C6PBX-5TtfqL-9cuF5c-bsfvhi-gSgQfo-5qg1iA-4fxT83-rj84nG-aqDFKL-aa62Yb-aWNNHD-4eGzDn-7QwGa9-9FNEDW-rViLHY-d93qSw-7hSEzV-dHwUKW-bKK1MT-bkkLg2-LYJ76C-Ndwsis-b4Uphx-axDf3k-dQkmqR-acUUZD-fjR8F-6ucocE-cwsuJG-avXLDv-a4SQH5-N9zsN-9n1KG1-qKPWhe-h75zPf-9sMDCr-ah4cz3-jNQ55-axDez2-5qSn9X-coh69L-9vKEnj",
            "https://www.figma.com/file/LKQ4FJ4bTnCSjedbRpk931/Sample-File",
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
            "https://youtube.com/vi/dQw4w9WgXcQ?",
            "https://twitter.com/beamapp"
        ]

        for string in strings {
            let url = URL(string: string)!
            XCTAssertFalse(st.canBuildEmbeddableContent(for: url))
        }
    }
}

