//
//  GRDBIndexer.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/04/2021.
//

import Foundation
import BeamCore
import GRDB

struct BeamElementRecord {
    var id: Int64?
    var title: String
    var uid: String
    var text: String
}

// SQL generation
extension BeamElementRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, uid, text
    }
}

// Fetching methods
extension BeamElementRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        uid = row[Columns.uid]
        text = row[Columns.text]
    }
}

// Persistence methods
extension BeamElementRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.uid] = uid
        container[Columns.text] = text
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class GRDBIndexer {
    var dbQueue: DatabasePool
    init(path: String) throws {
        let configuration = GRDB.Configuration()

        dbQueue = try DatabasePool(path: path, configuration: configuration)
        try dbQueue.write { db in
            // Create full-text tables
            try db.create(virtualTable: "BeamElementRecord", ifNotExists: true, using: FTS4()) { t in // or FTS3(), or FTS5()
//                t.compress = "zip"
//                t.uncompress = "unzip"
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("uid")
                t.column("text")
            }
        }
    }

    struct SearchResult {
        var title: String
        var uid: String
        var text: String?
    }

    func search(matchingAllTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(matchingAnyTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(matchingPhrase query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingPhrase: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(pattern: FTS3Pattern, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        do {
            let results = try dbQueue.read({ db -> [SearchResult] in
                try BeamElementRecord.matching(pattern).fetchAll(db).map({ record -> SearchResult in
                    return SearchResult(title: record.title, uid: record.uid, text: includeText ? record.text : nil)
                })
            })
            return results
        } catch {
            Logger.shared.logError("Search Error \(error)", category: .search)
            return []
        }
    }

    func append(note: BeamNote) throws {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
                for elem in note.allTexts {
                    try db.execute(
                        sql: "INSERT INTO BeamElementRecord (title, uid, text) VALUES (?, ?, ?)",
                        arguments: [note.title, elem.0.uuidString, elem.1.text])
                }
            }
        } catch {
            Logger.shared.logError("Error while indexing note \(note.title)", category: .search)
        }
    }

    func append(element: BeamElement) throws {
        guard let noteTitle = element.note?.title else { return }
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
                try db.execute(
                    sql: "INSERT INTO BeamElementRecord (title, uid, text) VALUES (?, ?, ?)",
                    arguments: [noteTitle, element.id.uuidString, element.text.text])
            }
        } catch {
            Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString)", category: .search)
        }
    }

    func remove(note: BeamNote) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
        }
    }

    func remove(noteTitled: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [noteTitled])
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteTitle = element.note?.title else { return }
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
        }
    }

    func clear() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord")
        }
    }

}
