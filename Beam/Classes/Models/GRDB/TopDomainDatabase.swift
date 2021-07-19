import GRDB

struct TopDomainDatabase {
    static let shared = makeShared()
    private var dbWriter: DatabaseWriter

    /// Creates a `GRDBDatabase`, and make sure the database schema is ready.
    init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter

        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDatabase") { db in
            try db.create(table: "topDomainRecord") { t in
                t.column("domainUrl", .text).unique()
                t.column("globalRank", .integer).unique()
            }

            try db.create(virtualTable: "topDomainRecordContent", using: FTS4()) { t in
                t.synchronize(withTable: "topDomainRecord")
                t.tokenizer = .unicode61(tokenCharacters: ["."])
                t.column("domainUrl")
                t.column("globalRank")
            }
        }

        try migrator.migrate(self.dbWriter)
    }

    private static func makeShared() -> TopDomainDatabase {
        do {
            let path = BeamData.dataFolder(fileName: "top_domains.db")
            let dbPool = try DatabasePool(path: path)

            return try TopDomainDatabase(dbPool)
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }

    public static func empty() throws -> TopDomainDatabase {
        return try TopDomainDatabase(DatabaseQueue())
    }
}

struct TopDomainRecord {
    let url: String
    let globalRank: Int
}

extension TopDomainRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case domainUrl, globalRank
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
        globalRank = row[Columns.globalRank]
    }
}

extension TopDomainRecord: MutablePersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container[Columns.domainUrl] = url
        container[Columns.globalRank] = globalRank
    }
}

enum TopDomainDatabaseError: Error {
    case notFound
}

extension TopDomainDatabase {
    public func insert(topDomain: inout TopDomainRecord) throws {
        try dbWriter.write { db in
            try topDomain.insert(db)
        }
    }

    public func clear() throws {
        _ = try dbWriter.write { db in
            try TopDomainRecord.deleteAll(db)
        }
    }

    /// Search the top domain database for the best hit completing the url.
    /// - Parameter url: prefix search
    public func search(withPrefix query: String) throws -> TopDomainRecord? {
        try dbWriter.read { db -> TopDomainRecord? in
            let pattern = try FTS3Pattern(rawPattern: query + "*")
            // Order by globalRank, but FTS returns row in ascending rowid. See `order` FTS parameter.
            // https://www.sqlite.org/fts3.html
            return try TopDomainRecord.joining(required: TopDomainRecord.content.matching(pattern))
                .fetchOne(db)
        }
    }

    public func search(withPrefix query: String,
                       completion: @escaping (Result<TopDomainRecord, Error>) -> Void) {
        dbWriter.asyncRead({ result in
            do {
                let db = try result.get()
                let pattern = try FTS3Pattern(rawPattern: query + "*")
                // Order by globalRank, but FTS returns row in ascending rowid. See `order` FTS parameter.
                // https://www.sqlite.org/fts3.html
                guard let result = try TopDomainRecord.joining(required: TopDomainRecord.content.matching(pattern))
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
}
