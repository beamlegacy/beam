//
//  PointAndShootTargetTest.swift
//  BeamTests
//
//  Created by Stef Kors on 09/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootTargetTest: PointAndShootTest {
    var iFrame: WebPositions.FrameInfo!
    var iFrameA: WebPositions.FrameInfo!
    var iFrameB: WebPositions.FrameInfo!
    var iFrameC: WebPositions.FrameInfo!
    var iFrame2: WebPositions.FrameInfo!
    let target: PointAndShoot.Target = PointAndShoot.Target(
        id: UUID().uuidString,
        rect: NSRect(x: 101, y: 102, width: 301, height: 302),
        mouseLocation: NSPoint(x: 201, y: 202),
        html: "<h1>Target</h1>",
        animated: false
    )

    let windowHref = TestWebPage.urlStr

    override func setUpWithError() throws {
        initTestBed()
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register window to framesInfo
        positions.framesInfo[windowHref] = WebPositions.FrameInfo(
            href: windowHref,
            parentHref: windowHref,
            x: 0,
            y: 0,
            scrollX: 0,
            scrollY: 0,
            width: 1000,
            height: 1000
        )

        iFrame = WebPositions.FrameInfo(href: "https://www.iframe.online", parentHref: windowHref, x: 100, y: 100, scrollX: 0, scrollY: 0, width: 900, height: 900)
        iFrameA = WebPositions.FrameInfo(href: "https://www.iframeA.online", parentHref: windowHref, x: 100, y: 100, scrollX: 0, scrollY: 0, width: 900, height: 450)
        iFrameB = WebPositions.FrameInfo(href: "https://www.iframeB.online", parentHref: windowHref, x: 100, y: 100, scrollX: 0, scrollY: 0, width: 900, height: 450)
        iFrameC = WebPositions.FrameInfo(href: "https://www.iframeC.online", parentHref: iFrameA.href, x: 100, y: 100, scrollX: 0, scrollY: 0, width: 900, height: 450)
        iFrame2 = WebPositions.FrameInfo(href: "https://www.iframe2.online", parentHref: iFrame.href, x: 100, y: 100, scrollX: 0, scrollY: 0, width: 800, height: 800)
    }

    /// When only the window frame is registered, translating the target shouldn't change the target.
    func testtranslateAndScaleTarget_noiFrames() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }

        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, windowHref)

        // We should have 1 window frame like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // +----------------------------------------+
        XCTAssertNil(translatedTarget)
        XCTAssertEqual(positions.framesInfo.count, 1, "Should contain 1 frameInfo objects")
        let finalTarget = translatedTarget ?? target
        XCTAssertEqual(finalTarget.rect, target.rect)
        XCTAssertEqual(finalTarget.mouseLocation, target.mouseLocation)
    }

    func testtranslateAndScaleTarget_noiFrames_scroll() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }

        // set scroll positions
        let scrollDelta: CGFloat = 33
        positions.setFrameInfoScroll(href: windowHref, scrollX: 0, scrollY: scrollDelta)

        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, windowHref)
        // We should have 1 window frame like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // +----------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 1, "Should contain 1 frameInfo objects")
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        // translateAndScaleTarget shouldn't change the location of the windowFrame.
        // The sendBounds function on the JS side takes care repositioning the Targets.
        XCTAssertNil(translatedTarget)
        let finalTarget = translatedTarget ?? target
        XCTAssertEqual(finalTarget.rect, expectedTarget.rect)
        XCTAssertEqual(finalTarget.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_singleiFrame_scroll_window() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // set scroll positions
        let scrollDeltaWindow: CGFloat = 87
        positions.setFrameInfoScroll(href: windowHref, scrollX: 0, scrollY: scrollDeltaWindow)
        // Register Frame to framesInfo
        positions.framesInfo[iFrame.href] = iFrame
        // We should have 2 frames nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // +-+--------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 2, "Should contain 2 frameInfo objects")
        // Assert Window
        let translatedWindowTarget = self.pns.translateAndScaleTargetIfNeeded(target, windowHref)
        let expectedWindowTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        // translateAndScaleTarget shouldn't change the location of the windowFrame.
        // The sendBounds function on the JS side takes care repositioning the Targets.
        XCTAssertNil(translatedWindowTarget)
        let finalWindowTarget = translatedWindowTarget ?? target
        XCTAssertEqual(finalWindowTarget.rect, expectedWindowTarget.rect)
        XCTAssertEqual(finalWindowTarget.mouseLocation, expectedWindowTarget.mouseLocation)

        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, iFrame.href)
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 201, y: 202 - scrollDeltaWindow, width: 301, height: 302),
            mouseLocation: NSPoint(x: 301, y: 215),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget)
        XCTAssertEqual(translatedTarget?.rect, expectedTarget.rect)
        XCTAssertEqual(translatedTarget?.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_singleiFrame_scroll_iframe() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register Frame to framesInfo
        positions.framesInfo[iFrame.href] = iFrame
        // set scroll positions
        let scrollDeltaFrame: CGFloat = 24
        positions.setFrameInfoScroll(href: iFrame.href, scrollX: 0, scrollY: scrollDeltaFrame)
        // We should have 2 frames nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // +-+--------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 2, "Should contain 2 frameInfo objects")
        // Assert Window
        let translatedWindowTarget = self.pns.translateAndScaleTargetIfNeeded(target, windowHref)
        let expectedWindowTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNil(translatedWindowTarget)

        let finalWindowTarget = translatedWindowTarget ?? target
        XCTAssertEqual(finalWindowTarget.rect, expectedWindowTarget.rect)
        XCTAssertEqual(finalWindowTarget.mouseLocation, expectedWindowTarget.mouseLocation)

        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, iFrame.href)
        // Scrolling in the iframe, shouldn't impact the x, y of the target in that iframe.
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(
                x: 101 + iFrame.x,
                y: 102 + iFrame.y - scrollDeltaFrame,
                width: 301,
                height: 302
            ),
            mouseLocation: NSPoint(x: 201  + iFrame.x, y: 202 + iFrame.y - scrollDeltaFrame),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget)
        XCTAssertEqual(translatedTarget?.rect, expectedTarget.rect)
        XCTAssertEqual(translatedTarget?.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_singleiFrame_scroll_both() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register Frame to framesInfo
        positions.framesInfo[iFrame.href] = iFrame
        // set scroll positions
        let scrollDeltaWindow: CGFloat = 66
        positions.setFrameInfoScroll(href: windowHref, scrollX: 0, scrollY: scrollDeltaWindow)
        let scrollDeltaFrame: CGFloat = 99
        positions.setFrameInfoScroll(href: iFrame.href, scrollX: 0, scrollY: scrollDeltaFrame)
        // We should have 2 frames nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // +-+--------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 2, "Should contain 2 frameInfo objects")
        // Assert Window
        let translatedWindowTarget = self.pns.translateAndScaleTargetIfNeeded(target, windowHref)
        let expectedWindowTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        // translateAndScaleTarget shouldn't change the location of the windowFrame.
        // The sendBounds function on the JS side takes care repositioning the Targets.
        XCTAssertNil(translatedWindowTarget)
        let finalWindowTarget = translatedWindowTarget ?? target
        XCTAssertEqual(finalWindowTarget.rect, expectedWindowTarget.rect)
        XCTAssertEqual(finalWindowTarget.mouseLocation, expectedWindowTarget.mouseLocation)

        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, iFrame.href)
        // Scrolling in the iframe, shouldn't impact the x, y of the target in that iframe.
        // However scrollin in the window frame, does impact the x, y of the target in the iframe
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(
                x: 101 + iFrame.x,
                y: 102 + iFrame.y - scrollDeltaWindow - scrollDeltaFrame,
                width: 301,
                height: 302
            ),
            mouseLocation: NSPoint(x: 201 + iFrame.x, y: 202 + iFrame.y - scrollDeltaWindow - scrollDeltaFrame),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget)
        XCTAssertEqual(translatedTarget?.rect, expectedTarget.rect)
        XCTAssertEqual(translatedTarget?.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_singleiFrame() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register Frame to framesInfo
        positions.framesInfo[iFrame.href] = iFrame
        // We should have 2 frames nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // +-+--------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 2, "Should contain 2 frameInfo objects")
        // Assert
        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, iFrame.href)
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101 + iFrame.x, y: 102 + iFrame.y, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201 + iFrame.x, y: 202 + iFrame.y),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget)
        XCTAssertEqual(translatedTarget?.rect, expectedTarget.rect)
        XCTAssertEqual(translatedTarget?.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_singleiFramesNested() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register Frames to framesInfo
        positions.framesInfo[iFrame.href] = iFrame
        positions.framesInfo[iFrame2.href] = iFrame2
        // We should have 3 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrame1                              |
        // | | +------------------------------------+
        // | | | iFrame2                            |
        // | | |                                    |
        // +-+-+------------------------------------+
        XCTAssertEqual(positions.framesInfo.count, 3, "Should contain 3 frameInfo objects")
        // Assert
        let translatedTarget = self.pns.translateAndScaleTargetIfNeeded(target, iFrame2.href)
        let expectedTarget: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 301, y: 302, width: 301, height: 302),
            mouseLocation: NSPoint(x: 401, y: 402),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget)
        XCTAssertEqual(translatedTarget?.rect, expectedTarget.rect)
        XCTAssertEqual(translatedTarget?.mouseLocation, expectedTarget.mouseLocation)
    }

    func testtranslateAndScaleTarget_iFramesNested_withSiblings() throws {
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        // Register Frames to framesInfo
        positions.framesInfo[iFrameA.href] = iFrameA
        positions.framesInfo[iFrameB.href] = iFrameB
        positions.framesInfo[iFrameC.href] = iFrameC
        // We should have 4 iframes nested like so:
        // +----------------------------------------+
        // | windowFrame                            |
        // | +--------------------------------------+
        // | | iFrameA                              |
        // | |                                      |
        // | |                                      |
        // | +--------------------------------------+
        // | | iFrameB                              |
        // | | +------------------------------------+
        // | | | iFrameC                            |
        // | | |                                    |
        // | | |                                    |
        // +-+-+------------------------------------+
        // Note: When the Target is located inside iFrame2. Only windowFrame, iFrameB and iFrame2
        //       will be used in calucating the Target location
        //
        XCTAssertEqual(positions.framesInfo.count, 4, "Should contain 4 frameInfo objects")
        // Siblings shouldn't intefere with siblings
        // Assert a target location in iFrameA
        let target_iFrameA: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        let translatedTarget_iFrameA = self.pns.translateAndScaleTargetIfNeeded(target_iFrameA, iFrameA.href)
        let expectedTarget_iFrameA: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 201, y: 202, width: 301, height: 302),
            mouseLocation: NSPoint(x: 301, y: 302),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget_iFrameA)
        XCTAssertEqual(translatedTarget_iFrameA?.rect, expectedTarget_iFrameA.rect)
        XCTAssertEqual(translatedTarget_iFrameA?.mouseLocation, expectedTarget_iFrameA.mouseLocation)
        //
        // Assert a target location in iFrameC
        let target_iFrameC: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 101, y: 102, width: 301, height: 302),
            mouseLocation: NSPoint(x: 201, y: 202),
            html: "<h1>Target</h1>",
            animated: false
        )
        let translatedTarget_iFrameC = self.pns.translateAndScaleTargetIfNeeded(target_iFrameC, iFrameC.href)
        let expectedTarget_iFrameC: PointAndShoot.Target = PointAndShoot.Target(
            id: UUID().uuidString,
            rect: NSRect(x: 301, y: 302, width: 301, height: 302),
            mouseLocation: NSPoint(x: 401, y: 402),
            html: "<h1>Target</h1>",
            animated: false
        )
        XCTAssertNotNil(translatedTarget_iFrameC)
        XCTAssertEqual(translatedTarget_iFrameC?.rect, expectedTarget_iFrameC.rect)
        XCTAssertEqual(translatedTarget_iFrameC?.mouseLocation, expectedTarget_iFrameC.mouseLocation)
    }
}
