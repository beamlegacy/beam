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
    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()

    override func setUp() {
        super.setUp()

        BeamTestsHelper.logout()
        PasswordManager.shared.deleteAll(includedRemote: false)
        Persistence.Encryption.localPrivateKey = Configuration.testPrivateKey
    }

    func testSavingPassword() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(allEntries.count > 0, "FetchAll has no passwords, it should be > 0")

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testUpdatingUsername() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let initialEntries = PasswordManager.shared.fetchAll()
        XCTAssertEqual(initialEntries.count, 1, "After first save, entry count should be 1")

        let initialEntry = PasswordManagerEntry(minimizedHost: Self.host.minimizedHost!, username: Self.username)
        PasswordManager.shared.save(entry: initialEntry, hostname: Self.host.minimizedHost!, username: "newuser@beamapp.co", password: Self.password)

        let updatedEntries = PasswordManager.shared.fetchAll()
        XCTAssertEqual(updatedEntries.count, 1, "After username change, entry count should still be 1")

        XCTAssertEqual(updatedEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(updatedEntries.last?.username, "newuser@beamapp.co")
        cleanupPasswordsAfterTest()
    }

    func testSavingPasswordOnBeamObjects() {
        beforeNetworkTests()

        let expectation = self.expectation(description: "save password")
        let newPassword = PasswordManager.shared.save(hostname: Self.host.minimizedHost!,
                                                      username: Self.username,
                                                      password: Self.password,
                                                      uuid: UUID(uuidString: "20D1B800-4436-4D25-8919-E23EF58FA13A")) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        guard let newPasswordUnwrapped = newPassword else {
            XCTFail("Password wasn't saved")
            return
        }

        do {
            var newPasswordReEncrypted = try PasswordEncryptionManager.reEncryptBeforeSend(newPasswordUnwrapped)
            let remotePassword: RemotePasswordRecord? = try beamObjectHelper.fetchOnAPI(newPasswordReEncrypted)
            XCTAssertNotNil(remotePassword, "Object doesn't exist on the API side?")

            if var remotePassword = remotePassword {
                // We need to decrypt passwords as both, even equal, will give different encrypted strings
                let decryptedPassword = try EncryptionManager.shared.decryptString(remotePassword.password) ?? "1"
                remotePassword.password = decryptedPassword
                newPasswordReEncrypted.password = try EncryptionManager.shared.decryptString(newPasswordReEncrypted.password) ?? "2"
                XCTAssertEqual(newPasswordReEncrypted, remotePassword)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        stopNetworkTests()
    }

    func testSavingPasswords() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let allEntries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(allEntries.count >= 2, "FetchAll has no passwords, it should be >= 2")

        let parentEntries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(parentEntries.count, 1)
        XCTAssertEqual(parentEntries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(parentEntries.last?.username, Self.username)

        let subdomainEntries = PasswordManager.shared.entries(for: Self.subdomain1.minimizedHost!, options: .exact)
        XCTAssertEqual(subdomainEntries.count, 1)
        XCTAssertEqual(subdomainEntries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(subdomainEntries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testDecodeOldObjectVersion() throws {
        let data = """
            {
              "created_at": "2021-07-13T08:55:06Z",
              "entry_id": "facebook.com foo@gmail.com",
              "host": "facebook.com",
              "name": "foo@gmail.com",
              "password": "",
              "updated_at": "2021-09-17T09:15:59Z",
              "uuid": "000008B1-9BF7-4D11-8CFC-381A81A30EA0"
            }
            """.asData
        let beamObject = BeamObject(id: UUID(uuidString: "000008B1-9BF7-4D11-8CFC-381A81A30EA0")!, beamObjectType: "password")
        beamObject.data = data

        let passwordRecord: RemotePasswordRecord = try beamObject.decodeBeamObject()
        XCTAssertEqual(passwordRecord.username, "foo@gmail.com")
        XCTAssertEqual(passwordRecord.hostname, "facebook.com")
    }

    func testDecodeNewObjectVersion() throws {
        let data = """
            {
              "created_at": "2021-07-13T08:55:06Z",
              "entry_id": "facebook.com foo@gmail.com",
              "hostname": "facebook.com",
              "username": "foo@gmail.com",
              "password": "",
              "updated_at": "2021-09-17T09:15:59Z",
              "uuid": "000008B1-9BF7-4D11-8CFC-381A81A30EA0"
            }
            """.asData
        let beamObject = BeamObject(id: UUID(uuidString: "000008B1-9BF7-4D11-8CFC-381A81A30EA0")!, beamObjectType: "password")
        beamObject.data = data

        let passwordRecord: RemotePasswordRecord = try beamObject.decodeBeamObject()
        XCTAssertEqual(passwordRecord.username, "foo@gmail.com")
        XCTAssertEqual(passwordRecord.hostname, "facebook.com")
    }

    func testFindEntriesForHost() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFindEntriesForHostWithParents() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.subdomain1.minimizedHost!, options: .fuzzy)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        XCTAssertEqual(entries.last?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFindEntriesForHostWithSubdomains() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, options: .fuzzy)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.last?.minimizedHost, Self.subdomain1.minimizedHost)
        XCTAssertEqual(entries.last?.username, Self.username)
        XCTAssertEqual(entries.first?.minimizedHost, Self.host.minimizedHost)
        XCTAssertEqual(entries.first?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testSearchEntries() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.find("git")
        XCTAssertTrue(entries.count > 0, "Find returns no passwords, should be > 0")
        let found = entries.filter { $0.minimizedHost == Self.host.minimizedHost }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.last?.username, Self.username)
        cleanupPasswordsAfterTest()
    }

    func testFetchAllEntries() {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let entries = PasswordManager.shared.fetchAll()
        XCTAssertTrue(entries.count > 0, "FetchAll has no passwords, it should be > 0")
        cleanupPasswordsAfterTest()
    }

    func testCount() {
        let beforeCount = PasswordManager.shared.count()
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)
        PasswordManager.shared.save(hostname: Self.subdomain1.minimizedHost!, username: Self.username, password: Self.password)
        let count = PasswordManager.shared.count()
        XCTAssertEqual(count - beforeCount, 2)
        cleanupPasswordsAfterTest()
    }

    func testGetPassword() throws {
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!, username: Self.username, password: Self.password)

        let password = try PasswordManager.shared.password(hostname: Self.host.minimizedHost!, username: Self.username)
        XCTAssertEqual(password, Self.password)
        cleanupPasswordsAfterTest()
    }

    func testDelete() {
        beforeNetworkTests()

        var expectation = self.expectation(description: "save password")
        PasswordManager.shared.save(hostname: Self.host.minimizedHost!,
                                    username: Self.username,
                                    password: Self.password,
                                    uuid: UUID(uuidString: "20D1B800-4436-4D25-8919-E23EF58FA13A")) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        expectation = self.expectation(description: "delete password")

        PasswordManager.shared.markDeleted(hostname: Self.host.minimizedHost!, for: Self.username) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        let entries = PasswordManager.shared.entries(for: Self.host.minimizedHost!, options: .exact)
        XCTAssertEqual(entries.count, 0)

        stopNetworkTests()
        cleanupPasswordsAfterTest()
    }

    private func beforeNetworkTests() {
        // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
        // back from Vinyl.
        BeamDate.freeze("2021-03-19T12:21:03Z")

        BeamTestsHelper.logout()

        beamHelper.beginNetworkRecording(test: self)
        BeamObjectManager.disableSendingObjects = false

        Configuration.beamObjectDirectCall = false
        BeamTestsHelper.login()
    }

    private func stopNetworkTests() {
        BeamObjectTestsHelper().deleteAll()
        beamHelper.endNetworkRecording()
        BeamDate.reset()
    }

    private func cleanupPasswordsAfterTest() {
        PasswordManager.shared.deleteAll(includedRemote: false)
    }
}
