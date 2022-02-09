//
//  ChromiumPasswordImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 20/12/2021.
//

import Foundation
import Combine
import GRDB
import CommonCrypto
import KeychainAccess
import BeamCore

struct ChromiumBrowserInfo {
    var browserType: BrowserType
    var keychainService: String
    var keychainAccount: String
    var databaseDirectory: String
}

extension ChromiumBrowserInfo {
    static let chrome = ChromiumBrowserInfo(browserType: .chrome, keychainService: "Chrome Safe Storage", keychainAccount: "Chrome", databaseDirectory: "Google/Chrome")
    static let brave = ChromiumBrowserInfo(browserType: .brave, keychainService: "Brave Safe Storage", keychainAccount: "Brave", databaseDirectory: "BraveSoftware/Brave-Browser")
}

/*
 Passwords database schema:
 CREATE TABLE meta(key LONGVARCHAR NOT NULL UNIQUE PRIMARY KEY, value LONGVARCHAR);
 CREATE TABLE logins (origin_url VARCHAR NOT NULL, action_url VARCHAR, username_element VARCHAR, username_value VARCHAR, password_element VARCHAR, password_value BLOB, submit_element VARCHAR, signon_realm VARCHAR NOT NULL, date_created INTEGER NOT NULL, blacklisted_by_user INTEGER NOT NULL, scheme INTEGER NOT NULL, password_type INTEGER, times_used INTEGER, form_data BLOB, date_synced INTEGER, display_name VARCHAR, icon_url VARCHAR, federation_url VARCHAR, skip_zero_click INTEGER, generation_upload_status INTEGER, possible_username_pairs BLOB, id INTEGER PRIMARY KEY AUTOINCREMENT, date_last_used INTEGER NOT NULL DEFAULT 0, moving_blocked_for BLOB, UNIQUE (origin_url, username_element, username_value, password_element, signon_realm));
 CREATE TABLE sqlite_sequence(name,seq);
 CREATE INDEX logins_signon ON logins (signon_realm);
 CREATE TABLE sync_entities_metadata (storage_key INTEGER PRIMARY KEY AUTOINCREMENT, metadata VARCHAR NOT NULL);
 CREATE TABLE sync_model_metadata (id INTEGER PRIMARY KEY AUTOINCREMENT, model_metadata VARCHAR NOT NULL);
 CREATE TABLE insecure_credentials (parent_id INTEGER REFERENCES logins ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED, insecurity_type INTEGER NOT NULL, create_time INTEGER NOT NULL, is_muted INTEGER NOT NULL DEFAULT 0, UNIQUE (parent_id, insecurity_type));
 CREATE INDEX foreign_key_index ON insecure_credentials (parent_id);
 CREATE TABLE stats (origin_domain VARCHAR NOT NULL, username_value VARCHAR, dismissal_count INTEGER, update_time INTEGER NOT NULL, UNIQUE(origin_domain, username_value));
 CREATE INDEX stats_origin ON stats(origin_domain);
 CREATE TABLE field_info (form_signature INTEGER NOT NULL, field_signature INTEGER NOT NULL, field_type INTEGER NOT NULL, create_time INTEGER NOT NULL, UNIQUE (form_signature, field_signature));
 CREATE INDEX field_info_index ON field_info (form_signature, field_signature);
 */

struct ChromiumPasswordItem: BrowserPasswordItem, Decodable, FetchableRecord {
    var url: URL
    var username: String
    var password: Data
    var dateCreated: Date?
    var dateLastUsed: Date?

    fileprivate enum CodingKeys: String, CodingKey {
        case url = "origin_url"
        case username = "username_value"
        case password = "password_value"
        case dateCreated = "date_created"
        case dateLastUsed = "date_last_used"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let urlStr = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: urlStr) ?? URL(string: String(urlStr.prefix(while: { $0 != "?" }))) else { throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid URL") }
        let dateCreated = try container.decode(Double.self, forKey: .dateCreated)
        let dateLastUsed = try container.decode(Double.self, forKey: .dateLastUsed)
        self.url = url
        self.username = try container.decode(String.self, forKey: .username)
        self.password = try container.decode(Data.self, forKey: .password)
        self.dateCreated = Date(timeIntervalSince1970: dateCreated)
        self.dateLastUsed = Date(timeIntervalSince1970: dateLastUsed)
    }
}

/**
 Passwords for Chromium-based browsers are stored in the `password_value`  column of the `logins` table, in a `Login Data` SQLite DB.
 Each entry starts with a 3-byte header (always `v10 in ASCII`) , foilowed by the encrypted password.
 On macOS, the passwords are encrypted in AES-128, CBC, IV = 16 0x20 bytes, with PKCS7 padding.
 The encryption key is derived from a secret stored in the keychain, using PBKDF2 (SHA-1, salt = `saltysalt`, 1003 iterations).
 The secret must be used as a string, even though it looks like it is base64-encoded.
 Implementation: https://source.chromium.org/chromium/chromium/src/+/main:components/os_crypt/os_crypt_mac.mm
 */

final class ChromiumPasswordImporter: ChromiumImporter {
    enum Error: Swift.Error {
        case secretNotFound
        case noDatabaseURL
        case keyDerivationFailed(status: OSStatus)
        case unknownPasswordHeader
        case decryptionFailed(status: OSStatus)
        case countNotAvailable
    }

    private func secretFromKeychain() throws -> String {
        let keychain = Keychain(service: browser.keychainService)
        guard let secret = try keychain.getString(browser.keychainAccount) else {
            throw Error.secretNotFound
        }
        return secret
    }

    static func derivedKey(secret: String) throws -> Data {
        let salt = "saltysalt"
        let iterations: UInt32 = 1003
        let keySize = 16
        var derivedKey = Data(count: keySize)
        let status = secret.withCString { secret in
            salt.withCString { salt -> Int32 in
                let saltLen = strlen(salt)
                return salt.withMemoryRebound(to: UInt8.self, capacity: saltLen + 1) { salt in
                    derivedKey.withUnsafeMutableBytes { (derived: UnsafeMutableRawBufferPointer) in
                        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), secret, strlen(secret), salt, saltLen, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), iterations, derived.bindMemory(to: UInt8.self).baseAddress, keySize)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw Error.keyDerivationFailed(status: status)
        }
        return derivedKey
    }

    static func decryptedPassword(for encryptedPassword: Data, using symmetricKey: Data) throws -> Data {
        guard let headerData = encryptedPassword.count > 3 ? encryptedPassword[0..<3] : nil, // should be "v10"
              String(data: headerData, encoding: .utf8) == "v10" else {
            throw Error.unknownPasswordHeader
        }
        let ivData = Data(repeating: 0x20, count: 16)
        let payloadData = Data(encryptedPassword[3...])
        let decryptedBufferSize = payloadData.count + 8 // more than enough for padding
        var decryptedData = Data(count: decryptedBufferSize)
        var dataMoved: Int = 0
        let status = symmetricKey.withUnsafeBytes { (symmetricKeyBuffer: UnsafeRawBufferPointer) in
            ivData.withUnsafeBytes { (ivBuffer: UnsafeRawBufferPointer) in
                payloadData.withUnsafeBytes { (payloadBuffer: UnsafeRawBufferPointer) in
                    decryptedData.withUnsafeMutableBytes { (decrypted: UnsafeMutableRawBufferPointer) in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding), symmetricKeyBuffer.baseAddress, symmetricKeyBuffer.count, ivBuffer.baseAddress, payloadBuffer.baseAddress, payloadBuffer.count, decrypted.baseAddress, 64, &dataMoved)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw Error.decryptionFailed(status: status)
        }
        decryptedData.count = dataMoved
        return decryptedData
    }

    private var currentSubject: PassthroughSubject<BrowserPasswordResult, Swift.Error>?

    private func passwordsDatabaseURL() throws -> URL? {
        guard let browserDirectory = try chromiumDirectory() else {
            return nil
        }
        return try SandboxEscape.endorsedURL(for: browserDirectory.appendingPathComponent("Login Data"))
    }
}

extension ChromiumPasswordImporter: BrowserPasswordImporter {
    var sourceBrowser: BrowserType {
        browser.browserType
    }

    var passwordsPublisher: AnyPublisher<BrowserPasswordResult, Swift.Error> {
        let subject = currentSubject ?? PassthroughSubject<BrowserPasswordResult, Swift.Error>()
        currentSubject = subject
        return subject.eraseToAnyPublisher()
    }

    func importPasswords() throws {
        guard let databaseURL = try passwordsDatabaseURL() else {
            throw Error.noDatabaseURL
        }
        let keychainSecret = try secretFromKeychain()
        try importPasswords(from: databaseURL, keychainSecret: keychainSecret)
    }

    func importPasswords(from databaseURL: URL, keychainSecret: String) throws {
        let symmetricKey = try Self.derivedKey(secret: keychainSecret)
        var configuration = GRDB.Configuration()
        configuration.readonly = true
        let dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        try dbQueue.read { db in
            do {
                guard let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM logins") else {
                    throw Error.countNotAvailable
                }
                // timestamps are number of microseconds since 1601-01-01, the SQL query converts them to seconds since UNIX Epoch.
                let rows = try ChromiumPasswordItem.fetchCursor(db, sql: "SELECT origin_url, username_value, password_value, date_created / 1000000 + strftime('%s', '1601-01-01 00:00:00') AS date_created, date_last_used / 1000000 + strftime('%s', '1601-01-01 00:00:00') AS date_last_used FROM logins")
                while let row = rows.nextPasswordItem(using: symmetricKey) {
                    currentSubject?.send(BrowserPasswordResult(itemCount: itemCount, item: row))
                }
                currentSubject?.send(completion: .finished)
            } catch {
                currentSubject?.send(completion: .failure(error))
            }
            currentSubject = nil
        }
    }
}

fileprivate extension RecordCursor where Record == ChromiumPasswordItem {
    func nextPasswordItem(using symmetricKey: Data) -> Record? {
        while true {
            do {
                guard var item = try next() else { return nil }
                item.password = try ChromiumPasswordImporter.decryptedPassword(for: item.password, using: symmetricKey)
                return item
            } catch {
                Logger.shared.logError("Couldn't import row: \(error)", category: .browserImport)
            }
        }
    }
}
