//
//  PointAndShootLeavePageTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest

import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootLeavePageTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testLeavePage() throws {
        // assert inital state
        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)
        XCTAssertNil(self.pns.shootConfirmationGroup)
        XCTAssertEqual(self.pns.collectedGroups.count, 0)
        XCTAssertEqual(self.pns.dismissedGroups.count, 0)
        XCTAssertFalse(self.pns.isAltKeyDown)
        XCTAssertFalse(self.pns.hasActiveSelection)

        // assign groups
        self.pns.activePointGroup = helperCreateRandomGroups()
        self.pns.activeSelectGroup = helperCreateRandomGroups()
        self.pns.activeShootGroup = helperCreateRandomGroups()
        self.pns.collectedGroups = [helperCreateRandomGroups(), helperCreateRandomGroups()]
        self.pns.dismissedGroups = [helperCreateRandomGroups(), helperCreateRandomGroups()]
        self.pns.shootConfirmationGroup = helperCreateRandomGroups()
        self.pns.isAltKeyDown = true
        self.pns.hasActiveSelection = true

        // assert groups are assigned values
        XCTAssertNotNil(self.pns.activePointGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        XCTAssertNotNil(self.pns.activeShootGroup)
        XCTAssertNotNil(self.pns.shootConfirmationGroup)
        XCTAssertEqual(self.pns.collectedGroups.count, 2)
        XCTAssertEqual(self.pns.dismissedGroups.count, 2)
        XCTAssertTrue(self.pns.isAltKeyDown)
        XCTAssertTrue(self.pns.hasActiveSelection)

        // call leavePage
        self.pns.leavePage()

        // assert post leavePage state
        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)
        XCTAssertNil(self.pns.shootConfirmationGroup)
        XCTAssertEqual(self.pns.collectedGroups.count, 0)
        XCTAssertEqual(self.pns.dismissedGroups.count, 0)
        XCTAssertFalse(self.pns.isAltKeyDown)
        XCTAssertFalse(self.pns.hasActiveSelection)
    }
}
