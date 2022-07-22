//
//  BeamVersionTests.swift
//  BeamCoreTests
//
//  Created by Sébastien Metrot on 13/07/2022.
//

import XCTest
import Foundation
@testable import BeamCore

class BeamVersionTests: XCTestCase {
    let id = UUID()
    let otherId = UUID()

    override func setUp() {
        BeamVersion.setupLocalDevice(id)
    }

    func testBasicComparisonsTruths() throws {
        let u1 = UUID()
        let u2 = UUID()
        let u3 = UUID()

        //        a -> j as (1,0,0) < (2,2,0)
        XCTAssert(BeamVersion([u1: 1, u2: 0, u3: 0]) < BeamVersion([u1: 2, u2: 2, u3: 0]))

        //        a -> b as (1,0,0) < (2,0,0)
        XCTAssert(BeamVersion([u1: 1, u2: 0, u3: 0]) < BeamVersion([u1: 2, u2: 0, u3: 0]))

        //        m -> k as (0,0,2) < (6,3,2)
        XCTAssert(BeamVersion([u1: 0, u2: 0, u3: 2]) < BeamVersion([u1: 6, u2: 3, u3: 2]))
    }

    func testSimpleIncrementalUpdate() throws {
        let version0 = BeamVersion()
        let version1 = version0.incremented()
        XCTAssert(version0 == version0)
        XCTAssert(version1 == version1)
        XCTAssert(version0 <= version1)
        XCTAssertFalse(version1 <= version0)
        XCTAssertFalse(version0 == version1)

        let version2 = version1.incremented()
        XCTAssert(version0 <= version2)
        XCTAssert(version1 <= version2)
        XCTAssertFalse(version2 <= version0)
        XCTAssertFalse(version2 <= version1)
        XCTAssert(version2 == version2)
        XCTAssertFalse(version1 == version2)
        XCTAssertFalse(version0 == version2)

        XCTAssertEqual(version0.compare(with: version0), .equal)
        XCTAssertEqual(version1.compare(with: version1), .equal)
        XCTAssertEqual(version2.compare(with: version2), .equal)

        XCTAssertEqual(version0.compare(with: version1), .ancestor)
        XCTAssertEqual(version1.compare(with: version0), .descendant)

        XCTAssertEqual(version1.compare(with: version2), .ancestor)
        XCTAssertEqual(version2.compare(with: version1), .descendant)

        XCTAssertEqual(version0.compare(with: version2), .ancestor)
        XCTAssertEqual(version2.compare(with: version0), .descendant)

        XCTAssertEqual(version0.compare(with: BeamVersion([:])), .descendant)
        XCTAssertEqual(version1.compare(with: BeamVersion([:])), .descendant)
        XCTAssertEqual(version2.compare(with: BeamVersion([:])), .descendant)
    }

    func testReceiveIncrementalUpdate() throws {
        let versionA0 = BeamVersion()
        let versionB0 = BeamVersion([UUID(): 0])
        XCTAssert(versionA0 == versionA0)
        XCTAssert(versionB0 == versionB0)
        XCTAssertFalse(versionA0 == versionB0)
        XCTAssertFalse(versionA0 <= versionB0)
        XCTAssertFalse(versionB0 <= versionA0)

        XCTAssertEqual(versionA0.compare(with: versionB0), .conflict)

        let merged = versionA0.receive(other: versionB0)
        XCTAssert(versionA0 <= merged)
        XCTAssertFalse(merged <= versionB0)
        XCTAssertEqual(versionA0.compare(with: merged), .ancestor)
        XCTAssertEqual(versionB0.compare(with: merged), .ancestor)
    }
}
