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
    static var dataFolder: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return paths.first ?? "~/Application Data/BeamApp/"
    }
    static var passwordsDBPath: String { return dataFolder + "/passwords.db" }

    static let host = URL(string: "http://www.github.com/signin")!
    static let username = "beamdev@beam.co"
    static let password = "BeamRocksss"

    var passwordsDB: PasswordsDB!
    var passwordsStore: PasswordStore!

    override func setUp() {
        super.setUp()
        do {
            passwordsDB = try PasswordsDB(path: Self.passwordsDBPath, dropTableFirst: true)

            passwordsStore = passwordsDB
            passwordsStore.fetchAll { passwords in
                XCTAssertEqual(passwords.count, 0)
            }
            
        } catch {
            XCTFail("PasswordsDB creation fail: \(error)")
            fatalError()
        }
    }

    func testSavingPassword() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.fetchAll { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.host.absoluteString, Self.host.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
        }
    }

    func testFindEntriesForHost() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.entries(for: Self.host) { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.host.absoluteString, Self.host.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
        }
    }

    func testSearchEntries() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.find("git") { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.host.absoluteString, Self.host.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
        }
    }

    func testFetchAllEntries() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.fetchAll { entries in
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.host.absoluteString, Self.host.minimizedHost)
            XCTAssertEqual(entries.first?.username, Self.username)
        }

    }

    func testGetPassword() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.password(host: Self.host, username: Self.username) { password in
            XCTAssertEqual(password, Self.password)

        }
    }

    func testDelete() {
        passwordsStore.save(host: Self.host, username: Self.username, password: Self.password)

        passwordsStore.delete(host: Self.host, username: Self.username)

        passwordsStore.fetchAll { passwords in
            XCTAssertEqual(passwords.count, 0)
        }
    }
}
