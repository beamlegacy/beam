import GRDB

struct TopDomainDatabase {
    static let shared = makeShared()
    private(set) var dbWriter: DatabaseWriter

    /// Creates a `GRDB Database`, and make sure the database schema is ready.
    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter

        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDatabase") { db in
            try db.create(table: "topDomainRecord") { t in
                t.column("domainUrl", .text).unique()
            }

            try db.create(virtualTable: "topDomainRecordContent", using: FTS4()) { t in
                t.synchronize(withTable: "topDomainRecord")
                t.tokenizer = .unicode61(tokenCharacters: ["."])
                t.column("domainUrl")
            }
        }
        try migrator.migrate(self.dbWriter)
    }

    private static func makeShared() -> TopDomainDatabase {
        do {
            let path = AppData.shared.dataFolder(fileName: "top_domains.db")
            let dbPool = try DatabasePool(path: path)

            return try TopDomainDatabase(dbPool)
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }
}

// MARK: - Used for tests
extension TopDomainDatabase {
    public static func empty() throws -> TopDomainDatabase {
        try TopDomainDatabase(DatabaseQueue())
    }
}
// MARK: -

struct TopDomainRecord {
    let url: String
}

extension TopDomainRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case domainUrl
    }

    struct FTS: TableRecord {
        static let databaseTableName = "topDomainRecordContent"
    }

    // Association to perform a key join on both `rowid` columns.
    static let content = hasOne(FTS.self, using: ForeignKey(["rowid"], to: ["rowid"]))
}

extension TopDomainRecord: FetchableRecord {
    init(row: Row) {
        url = row[Columns.domainUrl]
    }
}

extension TopDomainRecord: MutablePersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container[Columns.domainUrl] = url
    }
}

enum TopDomainDatabaseError: Error {
    case notFound
    case notAnURL
}

extension TopDomainDatabase {
    func clear() throws {
        _ = try dbWriter.write { db in
            try TopDomainRecord.deleteAll(db)
        }
    }

    func count() -> Int {
        (try? dbWriter.read { db in try TopDomainRecord.fetchCount(db) }) ?? 0
    }

    /// Search the top domain database for the best hit completing the url.
    /// - Parameter url: prefix search
    func search(withPrefix query: String) throws -> TopDomainRecord? {
        try dbWriter.read { db -> TopDomainRecord? in
            let pattern = try FTS3Pattern(rawPattern: query + "*")
            // Order by globalRank, but FTS returns row in ascending rowid. See `order` FTS parameter.
            // https://www.sqlite.org/fts3.html
            return try TopDomainRecord.joining(required: TopDomainRecord.content.matching(pattern))
                .fetchOne(db)
        }
    }

    func search(withPrefix query: String,
                completion: @escaping (Result<TopDomainRecord, Error>) -> Void) {
        dbWriter.asyncRead({ result in
            do {
                let db = try result.get()
                let pattern = try FTS3Pattern(rawPattern: query + "*")
                // Order by globalRank, but FTS returns row in ascending rowid. See `order` FTS parameter.
                // https://www.sqlite.org/fts3.html
                guard let result = try TopDomainRecord
                        .joining(required: TopDomainRecord.content.matching(pattern))
                        .fetchOne(db) else {
                            completion(.failure(TopDomainDatabaseError.notFound))
                            return
                        }
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        })
    }

    func add(_ topDomains: [String]) {
        do {
            try dbWriter.write { db in
                for topDomain in topDomains {
                    var record = TopDomainRecord(url: topDomain)
                    try record.insert(db)
                }
            }
        } catch {
            return
        }
    }
}
