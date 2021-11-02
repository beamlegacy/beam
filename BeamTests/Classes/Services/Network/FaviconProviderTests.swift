//
//  FaviconProviderTests.swift
//  BeamTests
//
//  Created by Remi Santos on 27/10/2021.
//

import XCTest
@testable import Beam

class FaviconProviderTests: XCTestCase {

    func testPickBestFaviconWithBestSizePNG() {

        let icons = [
            Favicon(url: URL(string: "f.co/icon.png?s=16")!, width: 16, height: 16, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=32")!, width: 32, height: 32, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=96")!, width: 96, height: 96, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=256")!, width: 256, height: 256, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=512")!, width: 512, height: 512, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico")!, origin: .webView)
        ]

        let resultFor16 = FaviconProvider().pickBestFavicon(icons, forSize: 16)
        XCTAssertNotNil(resultFor16)
        XCTAssertEqual(resultFor16?.width, 32)
        XCTAssertEqual(resultFor16?.url.absoluteString, "f.co/icon.png?s=32")

        let resultFor32 = FaviconProvider().pickBestFavicon(icons, forSize: 32)
        XCTAssertNotNil(resultFor32)
        XCTAssertEqual(resultFor32?.width, 96)
        XCTAssertEqual(resultFor32?.url.absoluteString, "f.co/icon.png?s=96")

        let resultFor34 = FaviconProvider().pickBestFavicon(icons, forSize: 34)
        XCTAssertNotNil(resultFor34)
        XCTAssertEqual(resultFor34?.width, 96)
        XCTAssertEqual(resultFor34?.url.absoluteString, "f.co/icon.png?s=96")
    }

    func testPickBestFaviconWithICO() {

        let icons = [
            Favicon(url: URL(string: "f.co/icon.ico?s=256")!, width: 96, height: 96, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico?s=128")!, width: 128, height: 128, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico?s=nil")!, origin: .webView)
        ]

        let resultFor32 = FaviconProvider().pickBestFavicon(icons, forSize: 32)
        XCTAssertNotNil(resultFor32)
        XCTAssertNil(resultFor32?.width)
        XCTAssertEqual(resultFor32?.url.absoluteString, "f.co/icon.ico?s=nil")
    }

}
