//
//  WebPositionsTest.swift
//  BeamTests
//
//  Created by Stef Kors on 11/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore
class WebPositionsTest: XCTestCase {
    let TestFramesInfo = [
        "https://www.windowFrame.com": Beam.WebPositions.FrameInfo(
            href: "https://www.windowFrame.com",
            parentHref: "https://www.windowFrame.com",
            x: 0.0,
            y: 0.0,
            scrollX: 0.0,
            scrollY: 200.0,
            width: 1211.0,
            height: 1231.0
        ),
        "https://www.iframe1.com": Beam.WebPositions.FrameInfo(
            href: "https://www.iframe1.com",
            parentHref: "https://www.windowFrame.com",
            x: 8.0,
            y: 50.0,
            scrollX: 0.0,
            scrollY: 23.0,
            width: 1197.0,
            height: 502.0
        ),
        "https://www.iframe2.com": Beam.WebPositions.FrameInfo(
            href: "https://www.iframe2.com",
            parentHref: "https://www.iframe1.com",
            x: 8.0,
            y: 50.0,
            scrollX: 0.0,
            scrollY: 44.0,
            width: 1181.0,
            height: 302.0
        )
    ]

    let webFrames = WebFrames()
    var webPositions: WebPositions!

    override func setUpWithError() throws {
        self.webPositions = WebPositions(webFrames: webFrames)
        self.webPositions.framesInfo = TestFramesInfo
    }

    func testRemoveSingleFrameFromFramesInfo() throws {
        XCTAssertEqual(self.webPositions.framesInfo.count, 3)
        self.webPositions.removeFrameInfo(from: "https://www.iframe1.com")
        XCTAssertEqual(self.webPositions.framesInfo.count, 2)
    }

    func testGetViewportPositionX_windowFrame() throws {
        let result = self.webPositions.viewportPosition("https://www.windowFrame.com", prop: WebPositions.FramePosition.x)
        XCTAssertEqual(result.reduce(0, +), 0)
    }

    func testGetViewportPositionX_iframe1() throws {
        let result = self.webPositions.viewportPosition("https://www.iframe1.com", prop: WebPositions.FramePosition.x)
        XCTAssertEqual(result.reduce(0, +), 8)
    }

    func testGetViewportPositionX_iframe2() throws {
        let result = self.webPositions.viewportPosition("https://www.iframe2.com", prop: WebPositions.FramePosition.x)
        XCTAssertEqual(result.reduce(0, +), 16)
    }

    func testGetViewportScrollX_windowFrame() throws {
        let result = self.webPositions.viewportPosition("https://www.windowFrame.com", prop: WebPositions.FramePosition.scrollY)
        XCTAssertEqual(result.reduce(0, +), 200)
    }

    func testGetViewportScrollX_iframe1() throws {
        let result = self.webPositions.viewportPosition("https://www.iframe1.com", prop: WebPositions.FramePosition.scrollY)
        XCTAssertEqual(result.reduce(0, +), 223)
    }

    func testGetViewportScrollX_iframe2() throws {
        let result = self.webPositions.viewportPosition("https://www.iframe2.com", prop: WebPositions.FramePosition.scrollY)
        XCTAssertEqual(result.reduce(0, +), 267)
    }

    func testSetFrameInfoScroll() throws {
        self.webPositions.setFrameInfoScroll(href: "https://www.iframe2.com", scrollX: 20, scrollY: 0)
        let result = self.webPositions.viewportPosition("https://www.iframe2.com", prop: WebPositions.FramePosition.scrollX)
        XCTAssertEqual(result.reduce(0, +), 20)
    }

    func testSetFrameInfoScroll_unregisteredFrame() throws {
        self.webPositions.setFrameInfoScroll(href: "https://www.rogue-nation.com", scrollX: 0, scrollY: 43)
        let result = self.webPositions.viewportPosition("https://www.rogue-nation.com", prop: WebPositions.FramePosition.scrollY)
        XCTAssertEqual(result.reduce(0, +), 0)

        let frameExists = self.webPositions.framesInfo["https://www.rogue-nation.com"] != nil
        XCTAssertEqual(frameExists, false)
    }
}
