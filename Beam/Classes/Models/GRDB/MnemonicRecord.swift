import GRDB

struct MnemonicRecord {
    var text: String
    var url: UUID
    var lastVisitedAt: Date
}

// SQL generation
extension MnemonicRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case text, url
        case lastVisitedAt = "last_visited_at"
    }
}

// Fetching methods
extension MnemonicRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        text = row[Columns.text]
        url = row[Columns.url]
        lastVisitedAt = row[Columns.lastVisitedAt]
    }
}

extension MnemonicRecord: PersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.text] = text
        container[Columns.url] = url
        container[Columns.lastVisitedAt] = lastVisitedAt
    }
}
