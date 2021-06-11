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

    private struct LineParser {
        var urlIndex: Int
        var usernameIndex: Int
        var passwordIndex: Int
        var expectedColumnCount: Int

        private static let columnSeparator = CharacterSet(charactersIn: ",;\t")
        private static let quotes = CharacterSet(charactersIn: "\"")

        init(header: String) throws {
            let headerColumns = header.lowercased().components(separatedBy: Self.columnSeparator)
            guard let urlIndex = headerColumns.firstIndex(of: "url"),
                  let usernameIndex = headerColumns.firstIndex(of: "username"),
                  let passwordIndex = headerColumns.firstIndex(of: "password") else {
                throw Error.headerNotFound
            }
            (self.urlIndex, self.usernameIndex, self.passwordIndex) = (urlIndex, usernameIndex, passwordIndex)
            expectedColumnCount = max(urlIndex, usernameIndex, passwordIndex) + 1
        }

        func decode(_ line: String) -> Entry? {
            let columns = line.components(separatedBy: Self.columnSeparator)
            guard columns.count >= expectedColumnCount else { return nil }
            let url = columns[urlIndex].trimmingCharacters(in: Self.quotes)
            let username = columns[usernameIndex].trimmingCharacters(in: Self.quotes)
            let password = columns[passwordIndex].trimmingCharacters(in: Self.quotes)
            guard !url.isEmpty, !username.isEmpty, !password.isEmpty else { return nil }
            return Entry(url: url, username: username, password: password)
        }
    }

    static func importPasswords(fromCSV file: URL, into store: PasswordStore) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        var lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            throw Error.unexpectedFormat
        }
        let header = lines.removeFirst()
        let parser = try LineParser(header: header)
        lines.forEach { line in
            if let entry = parser.decode(line) {
                store.save(host: entry.host, username: entry.username, password: entry.password)
            }
        }
    }
}
