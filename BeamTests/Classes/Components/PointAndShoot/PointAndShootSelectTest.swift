//
//  PointAndShootSelectTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/07/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class PointAndShootSelectTest: PointAndShootTest {

    override func setUpWithError() throws {
        initTestBed()
    }

    func testSelect_set() throws {
        let group = helperCreateRandomGroups()

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // required to allow setting the selection group
        self.pns.hasActiveSelection = true
        // calling select for the first time sets the activeSelectGroup
        self.pns.select(group.id, group.targets, group.text, group.href)

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        XCTAssertEqual(self.pns.activeSelectGroup?.id, group.id)
    }

    func testSelect_update() throws {
        let group = helperCreateRandomGroups()

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // required to allow setting the selection group
        self.pns.hasActiveSelection = true
        // calling select for the first time sets the activeSelectGroup
        self.pns.select(group.id, group.targets, group.text, group.href)

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        let group2 = helperCreateRandomGroups()
        // calling select for the second time with the same group id updates the activeSelectGroup
        self.pns.select(group.id, group2.targets, group.text, group.href)
        XCTAssertEqual(self.pns.activeSelectGroup?.id, group.id)
        // for example the target rect is equal
        if let activeGroup = self.pns.activeSelectGroup {
            for (index, target) in activeGroup.targets.enumerated() {
                XCTAssertEqual(target.rect, group2.targets[index].rect)
            }
        } else {
            XCTFail("expected activeGroup")
        }
    }

    func testSelect_update_differentId() throws {
        let group = helperCreateRandomGroups()

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // required to allow setting the selection group
        self.pns.hasActiveSelection = true
        // calling select for the first time sets the activeSelectGroup
        self.pns.select(group.id, group.targets, group.text, group.href)

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        let group2 = helperCreateRandomGroups()
        // Before group2 will be accepted we the selection should be collapsed
        // when the selection collapses it calls
        self.pns.clearSelection(group.id)
        // calling select for the second time with group2
        self.pns.select(group2.id, group2.targets, group2.text, group2.href)
        XCTAssertEqual(self.pns.activeSelectGroup?.id, group2.id)
        // for example the target rect is equal
        if let activeGroup = self.pns.activeSelectGroup {
            for (index, target) in activeGroup.targets.enumerated() {
                XCTAssertEqual(target.rect, group2.targets[index].rect)
            }
        } else {
            XCTFail("expected activeGroup")
        }
    }

    func testSelect_noActiveSelection() throws {
        let group = helperCreateRandomGroups()

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // required to allow setting the selection group
        self.pns.hasActiveSelection = false
        // calling select for the first time sets the activeSelectGroup
        self.pns.select(group.id, group.targets, group.text, group.href)

        // because hasActiveSelection is false, everything is still nil
        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)
    }

    func testSelectShoot() throws {
        let group = helperCreateRandomGroups()

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // required to allow setting the selection group
        self.pns.hasActiveSelection = true
        // calling select for the first time sets the activeSelectGroup
        self.pns.select(group.id, group.targets, group.text, group.href)

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNotNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // mouseKey event with option
        self.pns.refresh(NSPoint(x: 201, y: 202), [.option])

        // Select is now set as active ShootGroup
        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNotNil(self.pns.activeShootGroup)
        // match activeShootGroup with select group
        XCTAssertEqual(self.pns.activeShootGroup?.id, group.id)
        // for example the target rect is equal
        if let activeGroup = self.pns.activeShootGroup {
            for (index, target) in activeGroup.targets.enumerated() {
                XCTAssertEqual(target.rect, group.targets[index].rect)
            }
        } else {
            XCTFail("expected activeGroup")
        }
    }

    func testSelect_SelectShoot_Collect() throws {
        // calling select when group has been collect should update the targets
        let group = helperCreateRandomGroups()

        self.pns.collectedGroups = [group]
        // create a new set of targets
        guard let page = self.testPage,
              let positions = page.webPositions else {
                  XCTFail("expected test page")
                  return
              }
        positions.framesInfo[group.href] = WebFrames.FrameInfo(
            href: group.href,
            parentHref: group.href,
            scrollY: 300
        )
        let updatedTargets = group.targets.map({ target in
            self.pns.translateAndScaleTargetIfNeeded(target, group.href) ?? target
        })
        // send updated event with original group id
        self.pns.select(group.id, updatedTargets, group.text, group.href)

        XCTAssertNil(self.pns.activePointGroup)
        XCTAssertNil(self.pns.activeSelectGroup)
        XCTAssertNil(self.pns.activeShootGroup)

        // Not equal to the first set of targets
        if let activeGroup = self.pns.collectedGroups.first {
            for (index, target) in activeGroup.targets.enumerated() {
                XCTAssertEqual(target.rect.minX, group.targets[index].rect.minX)
                XCTAssertNotEqual(target.rect.minY, group.targets[index].rect.minY)
                XCTAssertEqual(target.rect.width, group.targets[index].rect.width)
                XCTAssertEqual(target.rect.height, group.targets[index].rect.height)
            }
        } else {
            XCTFail("expected activeGroup")
        }

        // for example the target rect is equal
        if let activeGroup = self.pns.collectedGroups.first {
            for (index, target) in activeGroup.targets.enumerated() {
                XCTAssertEqual(target.rect, updatedTargets[index].rect)
            }
        } else {
            XCTFail("expected activeGroup")
        }
    }
}
