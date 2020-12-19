//
//  BeamTextTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 19/12/2020.
//

import Foundation
import XCTest
@testable import Beam

class BeamTextTests: XCTestCase {
    func testCreation() {
        var btext = BeamText(text: "some string")
        XCTAssertEqual(btext.text, "some string")

        try? btext.insert(text: "new ", at: 5)
        XCTAssertEqual(btext.text, "some new string")

        try? btext.insert(text: "!", at: btext.text.count)
        XCTAssertEqual(btext.text, "some new string!")

        try? btext.insert(text: "!", at: btext.text.count, withAttributes: [.strong])
        XCTAssertEqual(btext.text, "some new string!!")

        try? btext.insert(text: "BLEH ", at: 5, withAttributes: [.strong])
        XCTAssertEqual(btext.text, "some BLEH new string!!")

        try? btext.remove(count: 5, at: 0)
        XCTAssertEqual(btext.text, "BLEH new string!!")
    }
}
