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

    var passwordManager: PasswordManager!

    override func setUp() {
        super.setUp()
        passwordManager = PasswordManager()
    }

    func testSavingPassword() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = passwordManager.fetchAll()
        XCTAssertTrue(allEntries.count > 0, "FetchAll has no passwords, it should be > 0")

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testSavingPasswords() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = passwordManager.fetchAll()
        XCTAssertTrue(allEntries.count >= 2, "FetchAll has no passwords, it should be >= 2")

        let parentEntries = passwordManager.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(parentEntries.count, 1)
        XCTAssertEqual(parentEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(parentEntries.last?.username, Self.username)

        let subdomainEntries = passwordManager.entries(for: Self.subdomain1.minimizedHost!, exact: true)
        XCTAssertEqual(subdomainEntries.count, 1)
        XCTAssertEqual(subdomainEntries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(subdomainEntries.last?.username, Self.username)
    }

    func testFindEntriesForHost() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testFindEntriesForHostWithParents() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.subdomain1.minimizedHost!, exact: false)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
    }

    func testFindEntriesForHostWithSubdomains() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(host: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, exact: false)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        XCTAssertEqual(entries.first?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
    }

    func testSearchEntries() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.find("git")
        XCTAssertTrue(entries.count > 0, "Find returns no passwords, should be > 0")
        let found = entries.filter { $0.minimizedHost == Self.host.minimizedHost }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.last?.username, Self.username)
    }

    func testFetchAllEntries() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.fetchAll()
        XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
    }

    func testGetPassword() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let password = passwordManager.password(host: Self.host.minimizedHost!, username: Self.username)
        XCTAssertEqual(password, Self.password)
    }

    func testDelete() {
        passwordManager.save(host: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        passwordManager.delete(host: Self.host.minimizedHost!, for: Self.username)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, exact: true)
        XCTAssertEqual(entries.count, 0)
    }
}
