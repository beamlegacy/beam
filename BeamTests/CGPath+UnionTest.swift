//
//  CGPath+UnionTest.swift
//  BeamTests
//
//  Created by Stef Kors on 02/08/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class CGPath_UnionTest: PointAndShootTest {
    func helperCreateFakeTargets(_ count: Int, _ offset: Int = 0) -> [PointAndShoot.Target] {
        var targets: [PointAndShoot.Target] = []

        for _ in 0..<count {
            let target = PointAndShoot.Target(
                id: UUID().uuidString,
                rect: NSRect(
                    x: (10 * count),
                    y: (10 * count) + offset,
                    width: 60,
                    height: 20
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
        let newTargets = self.helperCreateFakeTargets(10, 5)
        let id = UUID().uuidString
        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
        let beforeGroupPath = group.groupPath
        self.measure {
            group.updateTargets(id, newTargets)
        }
        // Assert the groupPath is updated
        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
    }

    func testCreate400() throws {
        let targets = self.helperCreateFakeTargets(400)
        let newTargets = self.helperCreateFakeTargets(400, 5)
        let id = UUID().uuidString
        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
        let beforeGroupPath = group.groupPath
        self.measure {
            group.updateTargets(id, newTargets)
        }
        // Assert the groupPath is updated
        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
    }

    func testCreate40000() throws {
        let targets = self.helperCreateFakeTargets(40000)
        let newTargets = self.helperCreateFakeTargets(40000, 5)
        let id = UUID().uuidString
        var group = PointAndShoot.ShootGroup(id, targets, faker.internet.url())
        let beforeGroupPath = group.groupPath
        self.measure {
            group.updateTargets(id, newTargets)
        }
        // Assert the groupPath is updated
        XCTAssertNotEqual(beforeGroupPath, group.groupPath)
    }

}
