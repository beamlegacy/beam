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
    static let frecency = hasOne(FrecencyNoteRecord.self, key: "frecency", using: FrecencyNoteRecord.BeamElementForeignKey)
    }

// SQL generation
extension BeamElementRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, text, uid, noteId
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
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
