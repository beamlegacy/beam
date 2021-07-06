//
//  PasswordsDBTests.swift
//  BeamTests
//
//  Created by Jean-Louis Darmon on 20/05/2021.
//

import Foundation
import XCTest

@testable import Beam
@testable import BeamCore
class PasswordsDBTests: XCTestCase {
    static let host = URL(string: "http://www.github.com/signin")!
    static let username = "beamdev@beam.co"
    static let password = "BeamRocksss"

    var passwordsStore: PasswordStore!

    override func setUp() {
        super.setUp()
        let passwordManager = PasswordsManager()
        passwordsStore = passwordManager.passwordsDB
    }

    func testSavingPassword() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.fetchAll { entries in
            XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
            XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
        }
    }

    func testFindEntriesForHost() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.entries(for: Self.host.minimizedHost!) { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
        }
    }

    func testSearchEntries() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.find("git") { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
        }
    }

    func testFetchAllEntries() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.fetchAll { entries in
            XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
            XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
        }

    }

    func testGetPassword() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.password(host: Self.host.minimizedHost!, username: Self.username) { password in
            XCTAssertEqual(password, Self.password)

        }
    }

    func testDelete() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.delete(host: Self.host.minimizedHost!, username: Self.username)

        passwordsStore.entries(for: Self.host.minimizedHost!) { entries in
            XCTAssertEqual(entries.count, 0)
        }
    }
}
