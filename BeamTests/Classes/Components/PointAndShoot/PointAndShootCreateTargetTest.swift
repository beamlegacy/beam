//
//  PointAndShootCreateTargetTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootCreateTargetTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testCreateTarget() throws {
        let id = UUID().uuidString
        let rect = NSRect(x: 0, y: 0, width: 10, height: 20)
        let href = "https://testPNS.online"
        let animated = false
        let html = "<p>writing paragraphs</p>"
        let mouseLocation = NSPoint(x: 3, y: 15)

        self.pns.mouseLocation = mouseLocation
        let target = self.pns.createTarget(id, rect, html, href, animated)

        XCTAssertEqual(target.mouseLocation, mouseLocation)
    }

    func testCreateTarget_clamp_mouselocation() throws {
        let id = UUID().uuidString
        let rect = NSRect(x: 0, y: 0, width: 10, height: 20)
        let href = "https://testPNS.online"
        let animated = false
        let html = "<p>writing paragraphs</p>"
        let mouseLocation = NSPoint(x: 300, y: 1000)

        self.pns.mouseLocation = mouseLocation
        let target = self.pns.createTarget(id, rect, html, href, animated)

        XCTAssertEqual(target.mouseLocation, NSPoint(x: 10, y: 20))
    }

}
