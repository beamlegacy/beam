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
        var generator = DistributedRandomGenerator<Double>(range: 0..<10, taken: [])
        let totalGenerated = 100
        for _ in 0..<totalGenerated {
            if let random = generator.randomElement() {
                generator.taken.append(random)
            }
        }
        XCTAssertEqual(generator.taken.count, totalGenerated)
        XCTAssertEqual(Set(generator.taken).count, totalGenerated)
    }

    func testUseTheLargestSpaceForRandom() {
        var generator = DistributedRandomGenerator<Double>(range: 0..<10, taken: [])

        generator.taken = [1] // random should be between 1..<10
        XCTAssertGreaterThan(generator.randomElement() ?? -1, 1)

        generator.taken = [1, 3] // random should be between 3..<10
        XCTAssertGreaterThan(generator.randomElement() ?? -1, 3)
        generator.taken = [7] // random should be between 0..<7
        XCTAssertLessThan(generator.randomElement() ?? 10, 7)
        generator.taken = [2, 8] // random should be between 2..<8
        XCTAssertLessThan(generator.randomElement() ?? 10, 8)
        XCTAssertGreaterThan(generator.randomElement() ?? -1, 2)

        generator.taken = [1, 2, 3, 4, 6, 7, 8, 9] // random should be between 4..<6
        XCTAssertLessThan(generator.randomElement() ?? 10, 6)
        XCTAssertGreaterThan(generator.randomElement() ?? -1, 4)
    }

}
