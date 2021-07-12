//
//  PasswordImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 05/06/2021.
//

import Foundation

enum PasswordImporter {
    enum Error: Swift.Error {
        case unexpectedFormat
        case headerNotFound
    }

    private struct Entry {
        var host: String
        var username: String
        var password: String

        init?(url: String, username: String, password: String) {
            let host: String
            if let separator = url.range(of: "://") {
                host = String(url.suffix(from: separator.upperBound))
            } else {
                host = url
            }
            self.host = host
            self.username = username
            self.password = password
        }
    }

    private struct RecordDecoder {
        var urlIndex: Int
        var usernameIndex: Int
        var passwordIndex: Int
        var expectedColumnCount: Int

        init(header: [String]) throws {
            let headerColumns = header.map { $0.lowercased() }
            guard let urlIndex = headerColumns.firstIndex(of: "url"),
                  let usernameIndex = headerColumns.firstIndex(of: "username"),
                  let passwordIndex = headerColumns.firstIndex(of: "password") else {
                throw Error.headerNotFound
            }
            (self.urlIndex, self.usernameIndex, self.passwordIndex) = (urlIndex, usernameIndex, passwordIndex)
            expectedColumnCount = max(urlIndex, usernameIndex, passwordIndex) + 1
        }

        func decode(_ columns: [String]) -> Entry? {
            guard columns.count >= expectedColumnCount else { return nil }
            let url = columns[urlIndex]
            let username = columns[usernameIndex]
            let password = columns[passwordIndex]
            guard !url.isEmpty, !username.isEmpty, !password.isEmpty else { return nil }
            return Entry(url: url, username: username, password: password)
        }
    }

    static func importPasswords(fromCSV text: String, into store: PasswordStore) throws {
        let seq = CSVUnescapingSequence(input: text)
        var parser = CSVParser(input: seq)

        guard let header = parser.next() else { throw Error.headerNotFound }
        let decoder = try RecordDecoder(header: header)

        for record in parser {
            if let entry = decoder.decode(record) {
                store.save(host: entry.host, username: entry.username, password: entry.password)
            }
        }
    }

    static func importPasswords(fromCSV file: URL, into store: PasswordStore) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        try importPasswords(fromCSV: text, into: store)
    }
}
