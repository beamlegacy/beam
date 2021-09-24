//
//  Csv.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/09/2021.
//

import Foundation

fileprivate extension String {
    var quotedForCSV: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private func toCsv(columns: [String]) -> String {
    return columns.map { "\($0)".quotedForCSV }.joined(separator: ",") + "\n"
}

func optionalToString<T>(_ elem: T?) -> String {
    guard let elem = elem else { return "<???>" }
    return "\(elem)"
}

protocol CsvRow {
    var columns: [String] { get }
    static var columnNames: [String] { get }
}

extension CsvRow {
    static var header: String { toCsv(columns: columnNames) }
    var row: String { toCsv(columns: columns) }

    func append(to fileHandle: FileHandle) {
        fileHandle.seekToEndOfFile()
        if let data = row.data(using: .utf8) { fileHandle.write(data) }
    }
}

class CsvRowsWriter {
    let header: String
    let rows: [CsvRow]

    init(header: String, rows: [CsvRow]) {
        self.header = header
        self.rows = rows
    }

    func append(to destination: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: destination.path) {
            defer {
                fileHandle.closeFile()
            }
            for row in rows { row.append(to: fileHandle) }
        } else {
            try overWrite(to: destination)
        }
    }
    func overWrite(to destination: URL) throws {
        let content = header + rows.map {$0.row} .joined()
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }
}
