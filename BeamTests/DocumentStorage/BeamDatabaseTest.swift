//
//  BeamDatabaseTest.swift
//  BeamCoreTests
//
//  Created by Sebastien Metrot on 16/05/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam
import GRDB

class BeamDatabaseTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    let dbPath = "file::memory:?cache=shared"
    var account: BeamAccount!
    var database: BeamDatabase!

    override func setUpWithError() throws {
        try super.setUpWithError()
        BeamDatabase.registerManager(BeamDocumentCollection.self)
        account = try! BeamAccount(id: UUID(), email: "test@beamapp.co", name: "test", path: "test-\(UUID())")
        database = BeamDatabase(account: account, id: UUID(), name: "testCollection")
    }

    override func tearDownWithError() throws {
        XCTAssertNoThrow(try account.delete(self))
    }

    func testInitedDatabaseHasNoManagers() {
        XCTAssertNil(database.collection)
        XCTAssertThrowsError(try database.manager(BeamDocumentCollection.self))
    }

    func testLoadedDatabaseHasManagers() {
        XCTAssertNoThrow(try database.load(overrideDatabasePath: dbPath))
        XCTAssertNotNil(database.collection)
        XCTAssertNoThrow(try database.manager(BeamDocumentCollection.self))
    }

    func testLoadedAndUnloadedDatabaseHasNoManagers() {
        XCTAssertNoThrow(try database.load(overrideDatabasePath: dbPath))
        XCTAssertNotNil(database.collection)
        XCTAssertNoThrow(try database.manager(BeamDocumentCollection.self))

        XCTAssertNoThrow(try database.unload())

        XCTAssertNil(database.collection)
        XCTAssertThrowsError(try database.manager(BeamDocumentCollection.self))
    }
}
