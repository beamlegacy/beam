//
//  StringCommonPrefixTests.swift
//  BeamCoreTests
//
//  Created by Sebastien Metrot on 20/01/2022.
//

import XCTest
@testable import BeamCore

class StringCommonPrefixTests: XCTestCase {

    func testCommonPrefixInString() throws {
        XCTAssertNil("Proud".longestCommonPrefixRange("ou"))
        XCTAssertEqual("P oud".longestCommonPrefixRange("ou"), 2..<4)
        XCTAssertEqual("P oud".longestCommonPrefixRange("Ou"), 2..<4)
        XCTAssertEqual("P,oud".longestCommonPrefixRange("Ou"), 2..<4)
        XCTAssertEqual("P,oud".longestCommonPrefixRange("Oud"), 2..<5)
        XCTAssertEqual("P,oud".longestCommonPrefixRange("Oudz"), 2..<5)
        XCTAssertEqual("Proud".longestCommonPrefixRange("pro"), 0..<3)
        XCTAssertEqual("Proud".longestCommonPrefixRange("protest"), 0..<3)
    }
}
