//
//  PasswordImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 05/06/2021.
//

import Foundation
import BeamCore

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

    static func importPasswords(fromCSV text: String) throws {
        let passwordManager = PasswordManager()
        let seq = CSVUnescapingSequence(input: text)
        var parser = CSVParser(input: seq)

        guard let header = parser.next() else { throw Error.headerNotFound }
        let decoder = try RecordDecoder(header: header)

        for record in parser {
            if let entry = decoder.decode(record) {
                passwordManager.save(host: entry.host.trimmingCharacters(in: CharacterSet(charactersIn: "/.\\")), username: entry.username, password: entry.password)
            }
        }
    }

    static func exportPasswords(toCSV file: URL) throws {
        let passwordManager = PasswordManager()
        let serialQueue = DispatchQueue(label: "exportPasswordsQueue")
        var allEntries: [PasswordManagerEntry] = []
        var csvString = "\("URL"),\("Username"),\("Password")\n"

        serialQueue.async {
            allEntries = passwordManager.fetchAll() ?? []
        }
        serialQueue.async {
            for entry in allEntries {
                if let passwordStr = passwordManager.password(host: entry.minimizedHost, username: entry.username) {
                    let row = encodeToCSV(entry: entry, password: passwordStr)
                    csvString.append("\(row)\n")
                }
            }
        }
        serialQueue.async {
            do {
                try csvString.write(to: file, atomically: true, encoding: .utf8)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .general)
            }
        }
    }

    static func encodeToCSV(entry: PasswordManagerEntry, password: String) -> String {
        [entry.minimizedHost, entry.username, password]
            .map(\.quotedForCSV)
            .joined(separator: ",")
    }

    static func importPasswords(fromCSV file: URL) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        try importPasswords(fromCSV: text)
    }
}

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
