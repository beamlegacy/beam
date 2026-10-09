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
    let passwordManager = PasswordManager()

    override func setUpWithError() throws {
        try super.setUpWithError()

        passwordManager.deleteAll()
        try EncryptionManager.shared.storeLocalPrivateKey(Configuration.testPrivateKey)
    }

    func testSavingPassword() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = passwordManager.fetchAll()
        XCTAssertTrue(allEntries.count > 0, "FetchAll has no passwords, it should be > 0")

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testUpdatingUsername() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let initialEntries = passwordManager.fetchAll()
        XCTAssertEqual(initialEntries.count, 1, "After first save, entry count should be 1")

        let initialEntry = PasswordManagerEntry(minimizedHost: Self.host.minimizedHost!, username: Self.username, neverSaved: false)
        passwordManager.save(entry: initialEntry, hostname: Self.host.minimizedHost!, username: "newuser@beamapp.co", password: Self.password)

        let updatedEntries = passwordManager.fetchAll()
        XCTAssertEqual(updatedEntries.count, 1, "After username change, entry count should still be 1")

        XCTAssertEqual(updatedEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(updatedEntries.last?.username, "newuser@beamapp.co")
        cleanupPasswordsAfterTest()
    }

    func testSavingPasswords() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = passwordManager.fetchAll()
        XCTAssertTrue(allEntries.count >= 2, "FetchAll has no passwords, it should be >= 2")

        let parentEntries = passwordManager.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(parentEntries.count, 1)
        XCTAssertEqual(parentEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(parentEntries.last?.username, Self.username)

        let subdomainEntries = passwordManager.entries(for: Self.subdomain1.minimizedHost!, options: .exact)
        XCTAssertEqual(subdomainEntries.count, 1)
        XCTAssertEqual(subdomainEntries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(subdomainEntries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFindEntriesForHost() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFindEntriesForHostWithParents() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.subdomain1.minimizedHost!, options: .fuzzy)
            .sorted { $0.minimizedHost > $1.minimizedHost }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFindEntriesForHostWithSubdomains() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, options: .fuzzy)
            .sorted { $0.minimizedHost > $1.minimizedHost }
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testSearchEntries() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.find("git")
        XCTAssertTrue(entries.count > 0, "Find returns no passwords, should be > 0")
        let found = entries.filter { $0.minimizedHost == Self.host.minimizedHost }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFetchAllEntries() {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = passwordManager.fetchAll()
        XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
        cleanupPasswordsAfterTest()
    }

    func testCount() {
        let beforeCount = passwordManager.count()
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        passwordManager.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)
        let count = passwordManager.count()
        XCTAssertEqual(count - beforeCount, 2)
        cleanupPasswordsAfterTest()
    }

    func testGetPassword() throws {
        passwordManager.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let password = try passwordManager.password(hostname: Self.host.minimizedHost!, username: Self.username)
        XCTAssertEqual(password, Self.password)
        cleanupPasswordsAfterTest()
    }

    func testDelete() {
        passwordManager.save(hostname: Self.host.minimizedHost!,
                             username: Self.username,
                             password: Self.password,
                             uuid: UUID(uuidString: "20D1B800-4436-4D25-8919-E23EF58FA13A"))
        passwordManager.markDeleted(hostname: Self.host.minimizedHost!, for: Self.username)

        let entries = passwordManager.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 0)
        cleanupPasswordsAfterTest()
    }

    private func cleanupPasswordsAfterTest() {
        passwordManager.deleteAll()
    }
}
