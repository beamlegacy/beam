//
//  PointAndShootCancelShootTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootCancelShootTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testCancelShoot_activeSelectGroup() throws {
        XCTAssertNil(self.pns.activeSelectGroup)
        self.pns.activeSelectGroup = helperCreateRandomGroup()
        XCTAssertNotNil(self.pns.activeSelectGroup)
        self.pns.cancelShoot()
        XCTAssertNil(self.pns.activeSelectGroup)
    }

    func testCancelShoot_activeShootGroup() throws {
        XCTAssertNil(self.pns.activeShootGroup)
        self.pns.activeShootGroup = helperCreateRandomGroup()
        XCTAssertNotNil(self.pns.activeShootGroup)
        self.pns.cancelShoot()
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testCancelShoot_activeShootGroup_and_activeShootGroup() throws {
        XCTAssertNil(self.pns.activeShootGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        self.pns.activeShootGroup = helperCreateRandomGroup()
        self.pns.activeSelectGroup = helperCreateRandomGroup()
        XCTAssertNotNil(self.pns.activeShootGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        self.pns.cancelShoot()
        XCTAssertNil(self.pns.activeShootGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
    }
}
