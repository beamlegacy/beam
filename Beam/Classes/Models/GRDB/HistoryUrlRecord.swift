import GRDB

struct HistoryUrlRecord {
    var id: Int64?
    var title: String
    var url: String
    var content: String
}

// SQL generation
extension HistoryUrlRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, url, title, content
    }
}

// Fetching methods
extension HistoryUrlRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        url = row[Columns.url]
        title = row[Columns.title]
        content = row[Columns.content] ?? ""
    }
}

// FTS search
extension HistoryUrlRecord {
    struct FTS: TableRecord {
        static let databaseTableName = "HistoryUrlContent"
    }

    // Association to perform a key join on both `rowid` columns.
    static let content = hasOne(FTS.self, using: ForeignKey(["rowid"], to: ["rowid"]))
}

extension HistoryUrlRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.url] = url
        container[Columns.title] = title
        container[Columns.content] = content
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
