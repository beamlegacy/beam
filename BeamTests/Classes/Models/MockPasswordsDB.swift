//
//  MockPasswordsDB.swift
//  BeamTests
//
//  Created by Frank Lefebvre on 22/12/2021.
//

import Foundation
@testable import Beam

final class MockPasswordsDB: PasswordStore {
    enum Error: Swift.Error {
        case notFound
    }

    var passwords: [LocalPasswordRecord]

    init() {
        passwords = []
    }

    func entries(for hostname: String, options: PasswordManagerHostLookupOptions) throws -> [LocalPasswordRecord] {
        passwords.filter { record in
            record.hostname == hostname
        }
    }

    func find(_ searchString: String) throws -> [LocalPasswordRecord] {
        passwords.filter { record in
            record.hostname.contains(searchString) || record.username.contains(searchString)
        }
    }

    func fetchAll() throws -> [LocalPasswordRecord] {
        passwords
    }

    func allRecords(_ updatedSince: Date?) throws -> [LocalPasswordRecord] {
        guard let updatedSince = updatedSince else {
            return passwords
        }
        return passwords.filter { record in
            record.updatedAt > updatedSince
        }
    }

    func passwordRecord(hostname: String, username: String) throws -> LocalPasswordRecord? {
        passwords.first { record in
            record.hostname == hostname && record.username == username
        }
    }

    func save(hostname: String, username: String, encryptedPassword: String, privateKeySignature: String, uuid: UUID?) throws -> LocalPasswordRecord {
        let record = LocalPasswordRecord(entryId: UUID().uuidString, hostname: hostname, username: username, password: encryptedPassword, createdAt: Date(), updatedAt: Date(), usedAt: Date())
        passwords.append(record)
        return record
    }

    func save(passwords: [LocalPasswordRecord]) throws {
        self.passwords = passwords
    }

    func update(record: LocalPasswordRecord, hostname: String, username: String, encryptedPassword: String, privateKeySignature: String, uuid: UUID?) throws -> LocalPasswordRecord {
        var newRecord = record
        newRecord.hostname = hostname
        newRecord.username = username
        newRecord.password = encryptedPassword
        if let uuid = uuid {
            newRecord.uuid = uuid
        }
        if let index = passwords.firstIndex(of: record) {
            passwords[index] = newRecord
        } else {
            passwords.append(newRecord)
        }
        return newRecord
    }

    func markUsed(record: LocalPasswordRecord) throws -> LocalPasswordRecord {
        var newRecord = record
        newRecord.usedAt = Date()
        if let index = passwords.firstIndex(of: record) {
            passwords[index] = newRecord
        } else {
            passwords.append(newRecord)
        }
        return newRecord
    }

    func markDeleted(hostname: String, username: String) throws -> LocalPasswordRecord {
        guard let index = passwords.firstIndex(where: { record in
            record.hostname == hostname && record.username == username
        }) else {
            throw Error.notFound
        }
        let record = passwords[index]
        passwords.remove(at: index)
        return record
    }

    func markAllDeleted() throws -> [LocalPasswordRecord] {
        passwords = []
        return []
    }

    func deleteAll() throws -> [LocalPasswordRecord] {
        passwords = []
        return []
    }

    func credentials(for hostname: String, completion: @escaping ([Credential]) -> Void) {
        let credentials = passwords.filter { record in
            record.hostname == hostname
        }.map { record in
            Credential(username: record.username, password: record.password)
        }
        completion(credentials)
    }
}
