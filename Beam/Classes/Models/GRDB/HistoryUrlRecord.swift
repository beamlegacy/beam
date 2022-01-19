import GRDB

struct HistoryUrlRecord {
    var urlId: UUID
    var lastVisitedAt: Date
    var title: String
    var aliasUrl: String
    var url: String
    var content: String
}

// SQL generation
extension HistoryUrlRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case urlId, url, title, content
        case lastVisitedAt = "last_visited_at"
        case aliasUrl = "alias_domain"
    }

    static let frecencyForeign = "frecency"
    static let frecency = hasOne(FrecencyUrlRecord.self,
                                 key: frecencyForeign,
                                 using: ForeignKey([FrecencyUrlRecord.Columns.urlId], to: [Columns.urlId]))
}

// Fetching methods
extension HistoryUrlRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        urlId = row[Columns.urlId]
        lastVisitedAt = row[Columns.lastVisitedAt]
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

extension HistoryUrlRecord: PersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.urlId] = urlId
        container[Columns.url] = url
        container[Columns.title] = title
        container[Columns.content] = content
        container[Columns.aliasUrl] = aliasUrl
        container[Columns.lastVisitedAt] = lastVisitedAt
    }
}
