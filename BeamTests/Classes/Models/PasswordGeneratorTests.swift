//
//  PasswordGeneratorTests.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 21/04/2022.
//

import XCTest
@testable import Beam

class PasswordGeneratorTests: XCTestCase {
    func testGeneratedPasswordContainsExpectedCharacters() {
        let password = PasswordGenerator.shared.generatePassword()
        XCTAssertEqual(password.count, 20)
        let blocks = password.components(separatedBy: "-")
        XCTAssertEqual(blocks.count, 3)
        for block in blocks {
            XCTAssertEqual(block.count, 6)
        }
        XCTAssertTrue(password.containsDigit)
        XCTAssertFalse(password.containsWhitespace)
        XCTAssertTrue(password.matches(withRegex: "[abcdefghijklmnopqrstuvwxyz]"))
        XCTAssertTrue(password.matches(withRegex: "[ABCDEFGHIJKLMNOPQRSTUVWXYZ]"))
    }

    func testGeneratedPasswordsAreDifferent() {
        let password1 = PasswordGenerator.shared.generatePassword()
        let password2 = PasswordGenerator.shared.generatePassword()
        XCTAssertNotEqual(password1, password2)
    }
}
