import GRDB

struct HistoryUrlRecord {
    var id: UUID?
    var title: String
    var aliasUrl: String
    var url: String
    var content: String
}

// SQL generation
extension HistoryUrlRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, urlId, url, title, content
        case aliasUrl = "alias_domain"
    }

    static let frecencyForeign = "frecency"
    static let frecency = hasOne(FrecencyUrlRecord.self,
                                 key: frecencyForeign,
                                 using: ForeignKey([Columns.urlId], to: [FrecencyUrlRecord.Columns.urlId]))
}

// Fetching methods
extension HistoryUrlRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        url = row[Columns.url]
        aliasUrl = row[Columns.aliasUrl] ?? ""
        title = row[Columns.title]
        content = row[Columns.content] ?? ""
    }
}

// FTS search
extension HistoryUrlRecord {
    struct FTS: TableRecord {
        static let databaseTableName = "historyUrlContent"
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
        container[Columns.aliasUrl] = aliasUrl
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
//        id = rowID
    }
}
