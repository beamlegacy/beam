//
//  DistributedRandomGeneratorTests.swift
//  BeamTests
//
//  Created by Remi Santos on 22/02/2022.
//

import XCTest
@testable import Beam

class DistributedRandomGeneratorTests: XCTestCase {

    func testUniqueValues() {
        var generator = DistributedRandomGenerator<Double>(range: 0..<10)
        let totalGenerated = 100
        for _ in 0..<totalGenerated {
            let random = generator.generate()
            generator.taken.append(random)
        }
        XCTAssertEqual(generator.taken.count, totalGenerated)
        XCTAssertEqual(Set(generator.taken).count, totalGenerated)
    }
}
