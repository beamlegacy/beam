//
//  CGPath+UnionTest.swift
//  BeamTests
//
//  Created by Stef Kors on 02/08/2021.
//

import XCTest
import Promises
import Nimble
import Fakery

@testable import Beam
@testable import BeamCore

class CGPath_UnionTest: PointAndShootTest {
    func helperCreateFakeTargets(_ count: Int) -> [PointAndShoot.Target] {
        var targets: [PointAndShoot.Target] = []

        for _ in 0..<count {
            let target = PointAndShoot.Target(
                id: UUID().uuidString,
                rect: NSRect(
                    x: (10 * count),
                    y: faker.number.randomInt(min: -12, max: 12),
                    width: faker.number.randomInt(min: 0, max: 12),
                    height: faker.number.randomInt(min: 0, max: 12)
                ),
                mouseLocation: NSPoint(x: 0, y: 0),
                html: "<p></p>",
                animated: false
            )
            targets.append(target)
        }

        return targets
    }
    
    override func setUpWithError() throws {
        initTestBed()
    }

    override func tearDownWithError() throws {}

    func testCreate10() throws {
        let targets = self.helperCreateFakeTargets(10)
        let newTargets = self.helperCreateFakeTargets(10)
        let id = UUID().uuidString
        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
        let beforeGroupPath = group.groupPath
        self.measure {
            group.updateTargets(id, newTargets)
        }
        // Assert the groupPath is updated
        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
    }

    func testCreate100() throws {
        let targets = self.helperCreateFakeTargets(100)
        let newTargets = self.helperCreateFakeTargets(100)
        let id = UUID().uuidString
        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
        let beforeGroupPath = group.groupPath
        self.measure {
            group.updateTargets(id, newTargets)
        }
        // Assert the groupPath is updated
        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
    }

//    func testCreate400() throws {
//        let targets = self.helperCreateFakeTargets(400)
//        let newTargets = self.helperCreateFakeTargets(400)
//        let id = UUID().uuidString
//        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
//        let beforeGroupPath = group.groupPath
//        self.measure {
//            group.updateTargets(id, newTargets)
//        }
//        // Assert the groupPath is updated
//        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
//    }

}
