//
//  BeamAccountTest.swift
//  BeamCoreTests
//
//  Created by Jérôme Blondon on 24/05/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam

import GRDB

class BeamAccountTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    let basePath = "test-\(UUID())"

    func testGetOrCreateDefaultDatabase() throws {
        let account = try BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: basePath)

        let database1 = account.getOrCreateDefaultDatabase()
        XCTAssertNotNil(database1)
        XCTAssertEqual(database1.title, "Default")

        XCTAssertEqual(account.databases.count, 1)

        let database2 = account.getOrCreateDefaultDatabase()
        XCTAssertEqual(database1, database2)

        XCTAssertNoThrow(try account.delete(self))
    }

    func testMultipleAccounts() throws {
        let account1 = try BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: "\(basePath)/account1")

        let database1 = account1.getOrCreateDefaultDatabase()
        XCTAssertNotNil(database1)
        XCTAssertEqual(database1.title, "Default")

        let account2 = try BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: "\(basePath)/account2")
        XCTAssertNotEqual(account1, account2)

        let database2 = account2.getOrCreateDefaultDatabase()
        XCTAssertNotNil(database2)
        XCTAssertEqual(database2.title, "Default")
        XCTAssertNotEqual(database1, database2)

        XCTAssertNoThrow(try account1.delete(self))
        XCTAssertNoThrow(try account2.delete(self))
    }

    func testSaveAndLoad() throws {
        if FileManager.default.fileExists(atPath: "\(basePath)/foo") {
            try FileManager.default.removeItem(atPath: "\(basePath)/foo")
        }
        XCTAssertThrowsError(try BeamAccount.load(fromFolder: "\(basePath)/foo"))
        let account = try BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: "\(basePath)/foo")
        XCTAssertNoThrow(try account.save())
        XCTAssertNoThrow(try BeamAccount.load(fromFolder: "\(basePath)/foo"))
    }
}
