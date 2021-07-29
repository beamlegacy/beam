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
    static let subdomain1 = URL(string: "http://subdomain.github.com/signin")!
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

    func testSavingPasswords() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordsStore.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.fetchAll { entries in
            XCTAssertTrue(entries.count >= 2, "FetchAll has no passwords, it should be >= 2")
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

    func testFindEntriesForHostWithParents() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordsStore.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.entries(for: Self.subdomain1.minimizedHost!, exact: false) { entries in
            XCTAssertEqual(entries.count, 2)
            XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
            XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
        }
    }

    func testFindEntriesForHostWithSubdomains() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordsStore.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.entries(for: Self.host.minimizedHost!, exact: false) { entries in
            XCTAssertEqual(entries.count, 2)
            XCTAssertEqual(entries.last?.minimizedHost, Self.subdomain1.minimizedHost)
            XCTAssertEqual(entries.last?.username, Self.username)
            XCTAssertEqual(entries.first?.minimizedHost, Self.host.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
        }
    }

    func testSearchEntries() {
        passwordsStore.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordsStore.find("git") { entries in
            XCTAssertTrue(entries.count > 0, "Find returns no passwords, should be > 0")
            let found = entries.filter { $0.minimizedHost == Self.host.minimizedHost }
            XCTAssertEqual(found.count, 1)
            XCTAssertEqual(found.last?.username, Self.username)
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
