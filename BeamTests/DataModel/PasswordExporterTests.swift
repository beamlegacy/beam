//
//  PasswordExporterTests.swift
//  BeamTests
//
//  Created by Beam on 10/08/2021.
//

import XCTest

@testable import Beam
@testable import BeamCore

class PasswordExporterTests: XCTestCase {
    func testExportSimpleEntry() {
        let entry = PasswordManagerEntry(minimizedHost: "test.beamapp.com", username: "user")
        let password = "simple password"
        let row = PasswordImporter.encodeToCSV(entry: entry, password: password)
        XCTAssertEqual(row, "\"test.beamapp.com\",\"user\",\"simple password\"")
    }

    func testExportPasswordWithComma() {
        let entry = PasswordManagerEntry(minimizedHost: "test.beamapp.com", username: "user")
        let password = "password,with,commas"
        let row = PasswordImporter.encodeToCSV(entry: entry, password: password)
        XCTAssertEqual(row, "\"test.beamapp.com\",\"user\",\"password,with,commas\"")
    }

    func testExportPasswordWithDoubleQuotes() {
        let entry = PasswordManagerEntry(minimizedHost: "test.beamapp.com", username: "user")
        let password = "a \"password\""
        let row = PasswordImporter.encodeToCSV(entry: entry, password: password)
        XCTAssertEqual(row, "\"test.beamapp.com\",\"user\",\"a \"\"password\"\"\"")
    }
}
