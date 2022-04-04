//
//  WebFramesTest.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 22/02/2022.
//

import XCTest

import Combine
@testable import Beam
@testable import BeamCore

class WebFramesTest: XCTestCase {
    var webFrames = WebFrames()
    var cancellables = Set<AnyCancellable>()
    var removedFrames = Set<String>()

    let webpage = WebFrames.FrameInfo(href: "https://www.webpage.com", parentHref: "https://www.webpage.com", x: 0, y: 0, scrollX: 0, scrollY: 0, width: 1000, height: 2000, isMain: true)
    let iframe1 = WebFrames.FrameInfo(href: "https://www.iframe1.com", parentHref: "https://www.webpage.com", x: 100, y: 100, scrollX: 0, scrollY: 0, width: 400, height: 200, isMain: false)
    let iframe1p = WebFrames.FrameInfo(href: "https://www.iframe1.com", parentHref: "https://www.iframe1.com", x: 100, y: 100, scrollX: 0, scrollY: 0, width: 400, height: 200, isMain: false)
    let iframe2 = WebFrames.FrameInfo(href: "https://www.iframe2.com", parentHref: "https://www.webpage.com", x: 100, y: 400, scrollX: 0, scrollY: 0, width: 400, height: 300, isMain: false)
    let iframe2p = WebFrames.FrameInfo(href: "https://www.iframe2.com", parentHref: "https://www.iframe2.com", x: 100, y: 400, scrollX: 0, scrollY: 0, width: 400, height: 300, isMain: false)
    let iframe3 = WebFrames.FrameInfo(href: "https://www.iframe3.com", parentHref: "https://www.webpage.com", x: 100, y: 700, scrollX: 0, scrollY: 0, width: 400, height: 400, isMain: false)
    let iframe3p = WebFrames.FrameInfo(href: "https://www.iframe3.com", parentHref: "https://www.iframe3.com", x: 100, y: 700, scrollX: 0, scrollY: 0, width: 400, height: 400, isMain: false)

    let iframe11 = WebFrames.FrameInfo(href: "https://www.iframe11.com", parentHref: "https://www.iframe1.com", x: 10, y: 10, scrollX: 0, scrollY: 0, width: 210, height: 10, isMain: false)
    let iframe11p = WebFrames.FrameInfo(href: "https://www.iframe11.com", parentHref: "https://www.iframe11.com", x: 10, y: 10, scrollX: 0, scrollY: 0, width: 210, height: 10, isMain: false)
    let iframe12 = WebFrames.FrameInfo(href: "https://www.iframe12.com", parentHref: "https://www.iframe1.com", x: 10, y: 20, scrollX: 0, scrollY: 0, width: 220, height: 10, isMain: false)
    let iframe12p = WebFrames.FrameInfo(href: "https://www.iframe12.com", parentHref: "https://www.iframe12.com", x: 10, y: 20, scrollX: 0, scrollY: 0, width: 220, height: 10, isMain: false)
    let iframe13 = WebFrames.FrameInfo(href: "https://www.iframe13.com", parentHref: "https://www.iframe1.com", x: 10, y: 30, scrollX: 0, scrollY: 0, width: 230, height: 10, isMain: false)
    let iframe13p = WebFrames.FrameInfo(href: "https://www.iframe13.com", parentHref: "https://www.iframe13.com", x: 10, y: 30, scrollX: 0, scrollY: 0, width: 230, height: 10, isMain: false)
    let iframe14 = WebFrames.FrameInfo(href: "https://www.iframe14.com", parentHref: "https://www.iframe1.com", x: 10, y: 40, scrollX: 0, scrollY: 0, width: 240, height: 10, isMain: false)
    let iframe14p = WebFrames.FrameInfo(href: "https://www.iframe14.com", parentHref: "https://www.iframe14.com", x: 10, y: 40, scrollX: 0, scrollY: 0, width: 240, height: 10, isMain: false)

    let redirected13p = WebFrames.FrameInfo(href: "https://www.redirected13.com", parentHref: "https://www.redirected13.com", x: 10, y: 30, scrollX: 0, scrollY: 0, width: 230, height: 10, isMain: false)
    let redirected14p = WebFrames.FrameInfo(href: "https://www.redirected14.com", parentHref: "https://www.redirected14.com", x: 10, y: 40, scrollX: 0, scrollY: 0, width: 240, height: 10, isMain: false)

    let iframe21 = WebFrames.FrameInfo(href: "https://www.iframe21.com", parentHref: "https://www.iframe2.com", x: 10, y: 10, scrollX: 0, scrollY: 0, width: 210, height: 11, isMain: false)
    let iframe21p = WebFrames.FrameInfo(href: "https://www.iframe21.com", parentHref: "https://www.iframe21.com", x: 10, y: 10, scrollX: 0, scrollY: 0, width: 210, height: 11, isMain: false)
    let iframe22 = WebFrames.FrameInfo(href: "https://www.iframe22.com", parentHref: "https://www.iframe2.com", x: 10, y: 20, scrollX: 0, scrollY: 0, width: 220, height: 11, isMain: false)
    let iframe22p = WebFrames.FrameInfo(href: "https://www.iframe22.com", parentHref: "https://www.iframe22.com", x: 10, y: 20, scrollX: 0, scrollY: 0, width: 220, height: 11, isMain: false)

    override func setUpWithError() throws {
        webFrames.removedFrames.sink { href in
            self.removedFrames.insert(href)
        }
        .store(in: &cancellables)
        webFrames.setFrames([webpage, iframe1, iframe2], isMain: true)
        webFrames.setFrames([iframe1p, iframe11, iframe12], isMain: false)
        webFrames.setFrames([iframe2p, iframe21, iframe22], isMain: false)
        webFrames.setFrames([iframe11p], isMain: false)
        webFrames.setFrames([iframe12p], isMain: false)
        webFrames.setFrames([iframe21p], isMain: false)
        webFrames.setFrames([iframe22p], isMain: false)
        XCTAssertEqual(webFrames.hrefTree.count, 7)
        XCTAssertEqual(webFrames.framesInfo.count, 7)
        XCTAssertEqual(removedFrames.count, 0)
    }

    func testChildMutation() throws {
        webFrames.setFrames([iframe1p, iframe13, iframe14], isMain: false)
        webFrames.setFrames([iframe13p], isMain: false)
        webFrames.setFrames([iframe14p], isMain: false)
        XCTAssertEqual(webFrames.hrefTree.count, 7)
        XCTAssertEqual(webFrames.framesInfo.count, 7)
        XCTAssertEqual(removedFrames.count, 2)
        XCTAssert(removedFrames.contains("https://www.iframe11.com"))
        XCTAssert(removedFrames.contains("https://www.iframe12.com"))
    }

    func testRootMutation() {
        webFrames.setFrames([webpage, iframe3], isMain: true)
        webFrames.setFrames([iframe3p], isMain: false)
        XCTAssertEqual(webFrames.hrefTree.count, 2)
        XCTAssertEqual(webFrames.framesInfo.count, 2)
        XCTAssertEqual(removedFrames.count, 6)
        XCTAssert(removedFrames.contains("https://www.iframe1.com"))
        XCTAssert(removedFrames.contains("https://www.iframe2.com"))
        XCTAssert(removedFrames.contains("https://www.iframe11.com"))
        XCTAssert(removedFrames.contains("https://www.iframe12.com"))
        XCTAssert(removedFrames.contains("https://www.iframe21.com"))
        XCTAssert(removedFrames.contains("https://www.iframe22.com"))
    }

    func testChildRedirection() throws {
        webFrames.setFrames([iframe1p, iframe13, iframe14], isMain: false)
        webFrames.setFrames([redirected13p], isMain: false)
        webFrames.setFrames([redirected14p], isMain: false)
        XCTAssertEqual(webFrames.hrefTree.count, 9)
        XCTAssertEqual(removedFrames.count, 2)
        XCTAssert(removedFrames.contains("https://www.iframe11.com"))
        XCTAssert(removedFrames.contains("https://www.iframe12.com"))
    }
}
