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

    var passwords: [PasswordRecord]

    init() {
        passwords = []
    }

    func entries(for hostname: String, options: PasswordManagerHostLookupOptions) throws -> [PasswordRecord] {
        passwords.filter { record in
            record.hostname == hostname
        }
    }

    func find(_ searchString: String) throws -> [PasswordRecord] {
        passwords.filter { record in
            record.hostname.contains(searchString) || record.username.contains(searchString)
        }
    }

    func fetchAll() throws -> [PasswordRecord] {
        passwords
    }

    func allRecords(_ updatedSince: Date?) throws -> [PasswordRecord] {
        guard let updatedSince = updatedSince else {
            return passwords
        }
        return passwords.filter { record in
            record.updatedAt > updatedSince
        }
    }

    func password(hostname: String, username: String) throws -> String? {
        try passwordRecord(hostname: hostname, username: username)?.password
    }

    func passwordRecord(hostname: String, username: String) throws -> PasswordRecord? {
        passwords.first { record in
            record.hostname == hostname && record.username == username
        }
    }

    func save(hostname: String, username: String, password: String, uuid: UUID?) throws -> PasswordRecord {
        let record = PasswordRecord(entryId: UUID().uuidString, hostname: hostname, username: username, password: password, createdAt: Date(), updatedAt: Date())
        passwords.append(record)
        return record
    }

    func save(passwords: [PasswordRecord]) throws {
        self.passwords = passwords
    }

    func update(record: PasswordRecord, hostname: String, username: String, password: String, uuid: UUID?) throws -> PasswordRecord {
        var newRecord = record
        newRecord.hostname = hostname
        newRecord.username = username
        newRecord.password = password
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

    func markDeleted(hostname: String, username: String) throws -> PasswordRecord {
        guard let index = passwords.firstIndex(where: { record in
            record.hostname == hostname && record.username == username
        }) else {
            throw Error.notFound
        }
        let record = passwords[index]
        passwords.remove(at: index)
        return record
    }

    func markAllDeleted() throws -> [PasswordRecord] {
        passwords = []
        return []
    }

    func deleteAll() throws -> [PasswordRecord] {
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
