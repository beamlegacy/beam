// swiftlint:disable file_length
//
//  WebPositionsMessageHandlerFrameBoundsTest.swift
//  BeamTests
//
//  Created by Stef Kors on 09/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

// swiftlint:disable type_body_length type_name file_length
class WebPositionsMessageHandlerFrameBoundsTest: PointAndShootTest {
    let windowHref = TestWebPage.urlStr
    var browserTabConfiguration: BeamWebViewConfigurationBase!
    var webPositionsMessageHandler: WebPositionsMessageHandler!
    var windowFrameBounds: [String: Any] = [
        "bounds": [
            "height": 1000,
            "width": 1000,
            "x": 0,
            "y": 0
        ],
        "href": "https://webpage.com"
    ]
    override func setUpWithError() throws {
        initTestBed()
        self.webPositionsMessageHandler = WebPositionsMessageHandler()
        self.browserTabConfiguration = BeamWebViewConfigurationBase(handlers: [webPositionsMessageHandler])
    }

    fileprivate func helperAssertFrameInfoEqual(_ frameInfo: WebPositions.FrameInfo, _ expectedFrameInfo: WebPositions.FrameInfo) {
        XCTAssertEqual(frameInfo.href, expectedFrameInfo.href, "href")
        XCTAssertEqual(frameInfo.x, expectedFrameInfo.x, "x")
        XCTAssertEqual(frameInfo.y, expectedFrameInfo.y, "y")
        XCTAssertEqual(frameInfo.scrollX, expectedFrameInfo.scrollX, "scrollX")
        XCTAssertEqual(frameInfo.scrollY, expectedFrameInfo.scrollY, "scrollY")
        XCTAssertEqual(frameInfo.width, expectedFrameInfo.width, "width")
        XCTAssertEqual(frameInfo.height, expectedFrameInfo.height, "height")
    }

    fileprivate func helperRegisterWindowFrameInfo() {
        // Register window frame
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Init window size and position
        let windowFrame = NSRect(x: 0, y: 0, width: 1000, height: 1000)

        // Register window to framesInfo
        positions.framesInfo[windowHref] = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: windowFrame.minX,
            y: windowFrame.minY,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    func testOnMessage_frameBounds_windowFrame() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send bounds of windowFrame
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds
                ]
            ],
            from: page,
            frameInfo: nil
        )

        XCTAssertEqual(positions.framesInfo.count, 1, "webPositions should contain 1 frameInfo")
        let expectedFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        XCTAssertEqual(positions.framesInfo[windowHref]?.href, expectedFrameInfo.href)
        XCTAssertEqual(positions.framesInfo[windowHref]?.parentHref, expectedFrameInfo.parentHref)
        XCTAssertEqual(positions.framesInfo[windowHref]?.x, expectedFrameInfo.x)
        XCTAssertEqual(positions.framesInfo[windowHref]?.y, expectedFrameInfo.y)
        XCTAssertEqual(positions.framesInfo[windowHref]?.scrollX, expectedFrameInfo.scrollX)
        XCTAssertEqual(positions.framesInfo[windowHref]?.scrollY, expectedFrameInfo.scrollY)
        XCTAssertEqual(positions.framesInfo[windowHref]?.width, expectedFrameInfo.width)
        XCTAssertEqual(positions.framesInfo[windowHref]?.height, expectedFrameInfo.height)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_iFrame() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame                               |
        // | |                                      |
        // +-+--------------------------------------+
        //
        // Will send two frameBounds events:
        //  - window frame bounds
        //  - iFrame frame bounds
        // these can arrive in any order and shouldn't overwrite a previously registered frame.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send iframe event
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        XCTAssertEqual(positions.framesInfo.count, 2, "webPositions should contain 2 frameInfos")

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)

        let expectediFrameInfo = WebPositions.FrameInfo(
            href: "https://www.iframe.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe.com/about-us"]!, expectediFrameInfo)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_iFrame_reverse_order() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame                               |
        // | |                                      |
        // +-+--------------------------------------+
        //
        // Will send two frameBounds events:
        //  - window frame bounds
        //  - iFrame frame bounds
        // these can arrive in any order and shouldn't overwrite a previously registered frame.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        // Send iframe event
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        XCTAssertEqual(positions.framesInfo.count, 2, "webPositions should contain 2 frameInfos")

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        guard let frame = positions.framesInfo[windowHref] else {
            XCTFail("borked")
            return
        }
        helperAssertFrameInfoEqual(frame, expectedWindowFrameInfo)

        let expectediFrameInfo = WebPositions.FrameInfo(
            href: "https://www.iframe.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe.com/about-us"]!, expectediFrameInfo)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_onLoad_frameBounds_sequence() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // This test simulates the full sequence of loading a page
        // Order of events:
        // - frameBounds "iFrame2"
        // - frameBounds "iFrame1"
        // - frameBounds "windowFrame"
        //
        // These event can arrive in any order and shouldn't overwrite or clear previously registered frames.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // A page containing a single iFrame, with that iFrame containing another iFrame.
        // Should have the following layout:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // | | +------------------------------------+
        // | | | iFrame2                            |
        // | | |                                    |
        // +-+-+------------------------------------+
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send frameBounds "iFrame2"
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe2.com",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        //
        // Send frameBounds "iFrame1"
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe1.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ],
                    [
                        "bounds": [
                            "height": 800,
                            "width": 800,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        //
        // Send onLoad "windowHref"
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        //
        // ASSERTS
        XCTAssertEqual(positions.framesInfo.count, 3, "webPositions should contain 3 frameInfos")

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)

        let expectediFrame1Info = WebPositions.FrameInfo(
            href: "https://www.iframe1.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe1.com/about-us"]!, expectediFrame1Info)

        let expectediFrame2Info = WebPositions.FrameInfo(
            href: "https://www.iframe2.com",
            parentHref: expectediFrame1Info.href,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 800,
            height: 800
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe2.com"]!, expectediFrame2Info)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_nested_iframes() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // We should have 3 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // | | +------------------------------------+
        // | | | iFrame2                            |
        // | | |                                    |
        // +-+-+------------------------------------+
        //
        // Will send two frameBounds events:
        //  - window frame bounds
        //  - iFrame frame bounds
        // these can arrive in any order and shouldn't overwrite a previously registered frame.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        // Send iframe1 event
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe1.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ],
                    [
                        "bounds": [
                            "height": 800,
                            "width": 800,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        // Send iframe3 event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe2.com",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )

        XCTAssertEqual(positions.framesInfo.count, 3, "webPositions should contain 3 frameInfos")

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)

        let expectediFrame1Info = WebPositions.FrameInfo(
            href: "https://www.iframe1.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe1.com/about-us"]!, expectediFrame1Info)

        let expectediFrame2Info = WebPositions.FrameInfo(
            href: "https://www.iframe2.com",
            parentHref: expectediFrame1Info.href,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 800,
            height: 800
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe2.com"]!, expectediFrame2Info)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_nested_iframes_reverse_order() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // We should have 3 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // | | +------------------------------------+
        // | | | iFrame2                            |
        // | | |                                    |
        // +-+-+------------------------------------+
        //
        // Will send two frameBounds events:
        //  - window frame bounds
        //  - iFrame frame bounds
        // these can arrive in any order and shouldn't overwrite a previously registered frame.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send iframe3 event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe2.com",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        // Send iframe1 event
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe1.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ],
                    [
                        "bounds": [
                            "height": 800,
                            "width": 800,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        XCTAssertEqual(positions.framesInfo.count, 3, "webPositions should contain 3 frameInfos")

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)

        let expectediFrame1Info = WebPositions.FrameInfo(
            href: "https://www.iframe1.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe1.com/about-us"]!, expectediFrame1Info)

        let expectediFrame2Info = WebPositions.FrameInfo(
            href: "https://www.iframe2.com",
            parentHref: expectediFrame1Info.href,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 0,
            width: 800,
            height: 800
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe2.com"]!, expectediFrame2Info)
    }

    func testOnMessage_frameBounds_windowFrame_Scroll() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // We should have 3 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // +----------------------------------------+
        //
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds
                ]
            ],
            from: page,
            frameInfo: nil
        )
        XCTAssertEqual(positions.framesInfo.count, 1, "webPositions should contain 1 frameInfos")
        // Send windowFrame scroll event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_scroll.rawValue,
            messageBody: [
                "href": windowHref,
                "height": 1000,
                "width": 1000,
                "scale": 1,
                "x": 0,
                "y": 200
            ],
            from: page,
            frameInfo: nil
        )
        XCTAssertEqual(positions.framesInfo.count, 1, "webPositions should still contain 1 frameInfos")
        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 200,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)
    }

    // swiftlint:disable:next function_body_length
    func testOnMessage_frameBounds_nested_iframes_Scroll() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("webPositions are required for test")
                  return
              }

        // Each frame on the page will send a "frameBounds" event
        // A page containing a single iFrame:
        //
        // We should have 3 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // | | +------------------------------------+
        // | | | iFrame2                            |
        // | | |                                    |
        // +-+-+------------------------------------+
        //
        // Will send two frameBounds events:
        //  - window frame bounds
        //  - iFrame frame bounds
        // these can arrive in any order and shouldn't overwrite a previously registered frame.
        // Any frame should be able to update it's values to support resizing and repositioning of html elements
        //
        // We expect to start with zero frames
        XCTAssertEqual(positions.framesInfo.count, 0, "webPositions should contain no frameInfo")
        // Send iframe3 event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe2.com",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        // Send iframe1 event
        // Note: The height and width might be a bit smaller (±2px) from what the parent sends
        //       The bounds provided by the parent should be leading
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": "https://www.iframe1.com/about-us",
                "frames": [
                    [
                        "bounds": [
                            "height": 888,
                            "width": 888,
                            "x": 0,
                            "y": 0
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ],
                    [
                        "bounds": [
                            "height": 800,
                            "width": 800,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe2.com"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        // Send windowFrame event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_frameBounds.rawValue,
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds,
                    [
                        "bounds": [
                            "height": 900,
                            "width": 900,
                            "x": 100,
                            "y": 100
                        ],
                        "href": "https://www.iframe1.com/about-us"
                    ]
                ]
            ],
            from: page,
            frameInfo: nil
        )
        XCTAssertEqual(positions.framesInfo.count, 3, "webPositions should contain 3 frameInfos")
        // Send windowFrame scroll event
        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_scroll.rawValue,
            messageBody: [
                "href": windowHref,
                "height": 1000,
                "width": 1000,
                "scale": 1,
                "x": 0,
                "y": 200
            ],
            from: page,
            frameInfo: nil
        )

        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_scroll.rawValue,
            messageBody: [
                "href": "https://www.iframe1.com/about-us",
                "height": 900,
                "width": 900,
                "scale": 1,
                "x": 0,
                "y": 330
            ],
            from: page,
            frameInfo: nil
        )

        self.webPositionsMessageHandler.onMessage(
            messageName: WebPositionsMessages.WebPositions_scroll.rawValue,
            messageBody: [
                "href": "https://www.iframe2.com",
                "height": 800,
                "width": 800,
                "scale": 1,
                "x": 0,
                "y": 30
            ],
            from: page,
            frameInfo: nil
        )

        let expectedWindowFrameInfo = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 200,
            width: 1000,
            height: 1000
        )
        helperAssertFrameInfoEqual(positions.framesInfo[windowHref]!, expectedWindowFrameInfo)

        let expectediFrame1Info = WebPositions.FrameInfo(
            href: "https://www.iframe1.com/about-us",
            parentHref: windowHref,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 330,
            width: 900,
            height: 900
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe1.com/about-us"]!, expectediFrame1Info)

        let expectediFrame2Info = WebPositions.FrameInfo(
            href: "https://www.iframe2.com",
            parentHref: expectediFrame1Info.href,
            x: 100,
            y: 100,
            scrollX: 0,
            scrollY: 30,
            width: 800,
            height: 800
        )

        helperAssertFrameInfoEqual(positions.framesInfo["https://www.iframe2.com"]!, expectediFrame2Info)
    }
}
