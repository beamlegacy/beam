//
//  PointAndShootMessageHandlerOnLoadTest.swift
//  BeamTests
//
//  Created by Stef Kors on 18/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootMessageHandlerOnLoadTest: PointAndShootTest {
    var browserTabConfiguration: BrowserTabConfiguration!
    var pointAndShootMessageHandler: PointAndShootMessageHandler!
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
        self.browserTabConfiguration = BrowserTabConfiguration()
        self.pointAndShootMessageHandler = PointAndShootMessageHandler(config: browserTabConfiguration)
    }

    func testOnMessage_onLoad_frameBounds() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        let windowHref = self.pns.page.url!.string
        self.pointAndShootMessageHandler.onMessage(
            messageName: "pointAndShoot_frameBounds",
            messageBody: [
                "href": windowHref,
                "frames": [
                    windowFrameBounds
                ]
            ],
            from: self.pns.page
        )
        XCTAssertEqual(positions.framesInfo.count, 1, "webPositions should contain 1 frameInfo")
    }
}
