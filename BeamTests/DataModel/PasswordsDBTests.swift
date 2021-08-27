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

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        PasswordManager.shared.deleteAll()
    }

    func testSavingPassword() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(allEntries.count > 0, "FetchAll has no passwords, it should be > 0")

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testSavingPasswords() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(allEntries.count >= 2, "FetchAll has no passwords, it should be >= 2")

        let parentEntries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(parentEntries.count, 1)
        XCTAssertEqual(parentEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(parentEntries.last?.username, Self.username)

        let subdomainEntries = PasswordManager.shared.entries(for: Self.subdomain1.minimizedHost!, exact: true)
        XCTAssertEqual(subdomainEntries.count, 1)
        XCTAssertEqual(subdomainEntries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(subdomainEntries.last?.username, Self.username)
    }

    func testFindEntriesForHost() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testFindEntriesForHostWithParents() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.subdomain1.minimizedHost!, exact: false)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testFindEntriesForHostWithSubdomains() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, exact: false)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        XCTAssertEqual(entries.first?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
    }

    func testSearchEntries() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.find("git")
        XCTAssertTrue(entries.count > 0, "Find returns no passwords, should be > 0")
        let found = entries.filter { $0.minimizedHost == Self.host.minimizedHost }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.last?.username, Self.username)
    }

    func testFetchAllEntries() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
    }

    func testGetPassword() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let password = PasswordManager.shared.password(host: Self.host.minimizedHost!, username: Self.username)
        XCTAssertEqual(password, Self.password)
    }

    func testDelete() {
        PasswordManager.shared.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        PasswordManager.shared.delete(host: Self.host.minimizedHost!, for: Self.username)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 0)
    }
}
