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

    struct PasswordExportResult {
        var exportedItems: Int
        var failedEntries: [PasswordManagerEntry]
    }

    private struct Entry {
        var hostname: String
        var username: String
        var password: String

        init?(url: String, username: String, password: String) {
            var host = url
            if let separator = host.range(of: "://") {
                host = String(host.suffix(from: separator.upperBound))
            }
            if host.hasPrefix("www.") {
                host = String(host.dropFirst("www.".count))
            }
            if let separator = host.range(of: "/") {
                host = String(host.prefix(upTo: separator.lowerBound))
            }
            if let separator = host.range(of: "?") {
                host = String(host.prefix(upTo: separator.lowerBound))
            }
            self.hostname = host.trimmingCharacters(in: CharacterSet(charactersIn: ".\\"))
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

    static func importPasswords(fromCSV text: String) throws -> Int {
        let seq = CSVUnescapingSequence(input: text)
        var parser = CSVParser(input: seq)

        guard let header = parser.next() else { throw Error.headerNotFound }
        let decoder = try RecordDecoder(header: header)

        var importedCount = 0
        for record in parser {
            if let entry = decoder.decode(record) {
                BeamData.shared.passwordManager.save(hostname: entry.hostname, username: entry.username, password: entry.password)
                importedCount += 1
            }
        }
        return importedCount
    }

    static func exportPasswords(toCSV file: URL, completion: ((PasswordExportResult) -> Void)? = nil) throws {
        let serialQueue = DispatchQueue(label: "exportPasswordsQueue", target: .userInitiated)

        serialQueue.async {
            let allEntries = BeamData.shared.passwordManager.fetchAll()
            var csvString = "\("URL"),\("Username"),\("Password")\n"
            var failedEntries: [PasswordManagerEntry] = []
            for entry in allEntries {
                if let passwordStr = try? BeamData.shared.passwordManager.password(hostname: entry.minimizedHost, username: entry.username, markUsed: false) {
                    let row = encodeToCSV(entry: entry, password: passwordStr)
                    csvString.append("\(row)\n")
                } else {
                    failedEntries.append(entry)
                }
            }
            do {
                try csvString.write(to: file, atomically: true, encoding: .utf8)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .general)
            }
            completion?(PasswordExportResult(exportedItems: allEntries.count - failedEntries.count, failedEntries: failedEntries))
        }
    }

    static func encodeToCSV(entry: PasswordManagerEntry, password: String) -> String {
        [entry.minimizedHost, entry.username, password]
            .map(\.quotedForCSV)
            .joined(separator: ",")
    }

    static func importPasswords(fromCSV file: URL) throws -> Int {
        let text = try String(contentsOf: file, encoding: .utf8)
        return try importPasswords(fromCSV: text)
    }
}

extension PasswordImporter.Error: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unexpectedFormat:
            return "Beam couldn't import your passwords because the file isn't in the expected format."
        case .headerNotFound:
            return "Beam couldn't import your passwords because the CSV file doesn't have the expected header."
        }
    }
}

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
