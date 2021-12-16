import GRDB

// Declare a record struct, data, how it is stored within the DB.
// Refer to GRDBDatabase for read/write operations.

// Previous version:
//struct BeamElementRecord {
//    var id: Int64?
//    var title: String
//    var uid: String
//    var text: String
//}

struct BeamElementRecord {
    var id: Int64?
    var title: String
    var text: String
    var uid: String
    var noteId: String // Added noteId
    var databaseId: String
    static let frecency = hasOne(FrecencyNoteRecord.self, key: "frecency", using: FrecencyNoteRecord.BeamElementForeignKey)
    }

// SQL generation
extension BeamElementRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, text, uid, noteId, databaseId
    }
}

// Fetching methods
extension BeamElementRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        text = row[Columns.text]
        uid = row[Columns.uid]
        noteId = row[Columns.noteId]
        databaseId = row[Columns.databaseId]
    }
}

// Persistence methods
extension BeamElementRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        // We can't associate the id with the one in a virtual table, it creates errors in SQLite
        container[Columns.title] = title
        container[Columns.text] = text
        container[Columns.uid] = uid
        container[Columns.noteId] = noteId
        container[Columns.databaseId] = databaseId
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

struct BeamNoteIndexingRecord {
    var id: Int64?
    var noteId: String
    var indexedAt: Date
}

// SQL generation
extension BeamNoteIndexingRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, noteId, indexedAt
    }
}

// Fetching methods
extension BeamNoteIndexingRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        noteId = row[Columns.noteId]
        indexedAt = row[Columns.indexedAt]
    }
}

// Persistence methods
extension BeamNoteIndexingRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        // We can't associate the id with the one in a virtual table, it creates errors in SQLite
        container[Columns.noteId] = noteId
        container[Columns.indexedAt] = indexedAt
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
