import GRDB

// Declare a record struct, data, how it is stored within the DB.
// Refer to GRDBDatabase for read/write operations.

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

