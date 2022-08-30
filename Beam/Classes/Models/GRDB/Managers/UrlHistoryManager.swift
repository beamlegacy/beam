//
//  URLHistoryManager.swift
//  Beam
//
//  Created by Sébastien Metrot on 10/06/2022.
//

import Foundation
import GRDB
import BeamCore

class UrlHistoryManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    static var id = UUID()

    static var name = "UrlHistoryManager"

    required init(holder: BeamManagerOwner? = nil, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    public override var tableNames: [String] { [
        BeamLinkDB.tableName,
        Link.FTS.databaseTableName,
        FrecencyUrlRecord.databaseTableName
    ] }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("createUrlHistoryManager") { db in
            try db.create(table: BeamLinkDB.tableName, ifNotExists: true) { table in
                table.column("id", .text).notNull().primaryKey().unique(onConflict: .replace)
                table.column("url", .text).notNull().indexed().unique(onConflict: .replace)
                table.column("title", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).indexed().notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
                table.column("content", .text).defaults(to: "")
                table.column("destination", .blob).indexed()
                table.column("frecencyVisitLastAccessAt", .date)
                table.column("frecencyVisitScore", .double)
                table.column("frecencyVisitSortScore", .double)
            }

            // Index title and text in FTS from Link.
            try db.create(virtualTable: Link.FTS.databaseTableName, using: FTS4()) { t in
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
                t.synchronize(withTable: BeamLinkDB.tableName)
            }

            try db.create(table: FrecencyUrlRecord.databaseTableName, ifNotExists: true) { t in
                t.column("urlId", .text) // FIXME: with .references("linkStore", column: "urlId")
                t.column("lastAccessAt", .date)
                t.column("frecencyScore", .double)
                t.column("frecencySortScore", .double)
                t.column("frecencyKey")
                t.primaryKey(["urlId", "frecencyKey"])
            }

        }
    }

    func getLinks(matchingUrl url: String) -> [UUID: Link] {
        var matchingLinks = [UUID: Link]()
        try? self.read { db in
            try Link.filter(Column("url").like("%\(url)%"))
                .fetchAll(db)
                .forEach { matchingLinks[$0.id] = $0 }
        }
        return matchingLinks
    }

    public struct LinkWithDestination: FetchableRecord {
        var link: Link
        var destinationLink: Link?

        init(row: Row) {
            link = Link(row: row)
            destinationLink = row["destinationLink"]
        }
    }

    func getTopScoredLinks(matchingUrl url: String, frecencyParam: FrecencyParamKey, limit: Int = 10) -> [LinkSearchResult] {
        let destinationAlias = TableAlias()
        let association = Link.destinationLink.aliased(destinationAlias)
        let query = Link
            .filter(Column("url").like("%.\(url)%") || Column("url").like("%/\(url)%"))
            .including(optional: association)
            .order((destinationAlias["frecencyVisitSortScore"] ?? Link.Columns.frecencyVisitSortScore).desc)
            .limit(limit)

        return (try? self.read { db in
            let links = try LinkWithDestination.fetchAll(db, query)
            return links.map { record in
                LinkSearchResult(title: record.link.title,
                                 url: record.link.url,
                                 frecencySortScore: record.destinationLink?.frecencyVisitSortScore ?? record.link.frecencyVisitSortScore,
                                 destinationURL: record.destinationLink?.url)
            }
        }) ?? []
    }

    func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID {
        (try? self.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)?.id
        }) ?? visit(url: url, title: title, content: content, destination: destination).id
    }

    func insert(links: [Link]) throws {
        try self.write { db in
            for var link in links {
                try link.insert(db)
            }
        }
    }

    func linkFor(id: UUID) -> Link? {
        try? self.read { db in
            try Link.filter(Column("id") == id).fetchOne(db)
        }
    }
    func getLinks(ids: [UUID]) throws -> [UUID: Link] {
        try self.read { db in
            let cursor = try Link
                .filter(ids.contains(Link.Columns.id))
                .fetchCursor(db)
                .map { ($0.id, $0) }
            return try Dictionary(uniqueKeysWithValues: cursor)
        }
    }

    func linkFor(url: String) -> Link? {
        try? self.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)
        }
    }

    @discardableResult
    func visit(url: String, title: String? = nil, content: String?, destination: String?) -> Link {
        guard var link = linkFor(url: url) else {
            // The link doesn't exist, create it and return the id
            var link = Link(url: url, title: title, content: content)
            link.setDestination(destination)
            _ = try? self.write { db in
                try link.insert(db)
            }
            return link
        }

        // otherwise let's update the title and the updatedAt
        if title?.isEmpty == false {
            link.title = title
        }
        link.content = content
        link.setDestination(destination)
        link.updatedAt = BeamDate.now

        _ = try? self.write { db in
            try link.update(db, columns: [Column("updateAt"), Column("title"), Column("content"), Column("destination")])
        }
        return link
    }
    func updateLinkFrecency(id: UUID, lastAccessAt: Date, score: Float, sortScore: Float) {
        guard var link = linkFor(id: id) else { return }
        link.frecencyVisitLastAccessAt = lastAccessAt
        link.frecencyVisitScore = score
        link.frecencyVisitSortScore = sortScore
        link.updatedAt = BeamDate.now

        let updateColumns = [
            Column("updatedAt"),
            Column("frecencyVisitLastAccessAt"),
            Column("frecencyVisitScore"),
            Column("frecencyVisitSortScore")
        ]
        _ = try? self.write { db in
            try link.update(db, columns: updateColumns)
        }
    }

    func updateLinkFrecencies(scores: [FrecencyScore]) {
        let q = """
                UPDATE link
                SET
                    updatedAt = :updatedAt,
                    frecencyVisitLastAccessAt = :lastAccessAt,
                    frecencyVisitScore = :score,
                    frecencyVisitSortScore = :sortScore
                WHERE id = :id
                """
        let now = BeamDate.now
        do {
            _ = try self.write { db in
                for score in scores {
                    let arguments: StatementArguments = [
                        "updatedAt": now,
                        "lastAccessAt": score.lastTimestamp,
                        "score": score.lastScore,
                        "sortScore": score.sortValue,
                        "id": score.id
                    ]
                    try db.execute(sql: q, arguments: arguments)
                }
            }
        } catch {
            Logger.shared.logError("Couldn't update link frecencies: \(error)", category: .database)
        }
    }

    func allLinks(updatedSince: Date?) throws -> [Link] {
        guard let updatedSince = updatedSince
        else {
            return try self.read { db in try Link.fetchAll(db) }
        }
        return try self.read { db in
            try Link.filter(Column("updatedAt") >= updatedSince).fetchAll(db)
        }
    }

    func getLinks(ids: [UUID]) throws -> [Link] {
        try self.read { db in
            try Link.filter(keys: ids).fetchAll(db)
        }
    }

    func insertOrIgnore(links: [Link]) throws {
        try self.write { db in
            for var link in links where try !link.exists(db) {
                try link.insert(db)
            }
        }
    }

    // Search History and Aliases:
    public struct LinkSearchResult {
        let title: String?
        let url: String
        let frecencySortScore: Float?
        var destinationURL: String?
    }

    public struct LinkWithFrecency: FetchableRecord {
        var link: Link
        var frecency: FrecencyUrlRecord?

        init(row: Row) {
            link = Link(row: row)
            frecency = row[Link.frecencyForeign]
        }
    }

    /// Perform a history search query.
    /// - Parameter prefixLast: when enabled the last token is prefix matched.
    /// - Parameter enabledFrecencyParam: select the frecency parameter to use to sort results.
    func searchLink(query: String,
                    prefixLast: Bool = true,
                    enabledFrecencyParam: FrecencyParamKey? = nil,
                    limit: Int = 10,
                    completion: @escaping (Result<[LinkSearchResult], Error>) -> Void) {
        guard var pattern = FTS3Pattern(matchingAllTokensIn: query) else {
            completion(.failure(BeamNoteLinksAndRefsManager.ReadError.invalidFTSPattern))
            return
        }
        if prefixLast {
            guard let prefixLastPattern = try? FTS3Pattern(rawPattern: pattern.rawPattern + "*") else {
                completion(.failure(BeamNoteLinksAndRefsManager.ReadError.invalidFTSPattern))
                return
            }
            pattern = prefixLastPattern
        }

        asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let joint = PreferencesManager.includeHistoryContentsInOmniBox ? Link.contentAssociation.matching(pattern) : Link.contentAssociation.filter(Column("title").match(pattern))

                let db = try dbResult.get()
                let destinationAlias = TableAlias()
                let association = Link.destinationLink.aliased(destinationAlias)
                let request = Link
                    .joining(required: joint)
                    .including(optional: association)
                    .order((destinationAlias["frecencyVisitSortScore"] ?? Link.Columns.frecencyVisitSortScore).desc)
                    .limit(limit)

                let results = try request
                    .asRequest(of: LinkWithDestination.self)
                    .fetchAll(db)
                    .map { record -> LinkSearchResult in
                        Logger.shared.logDebug("Found \(record.link.url) - with frecency: \(String(describing: record.link.frecencyVisitSortScore))", category: .search)
                        return LinkSearchResult(
                            title: record.link.title,
                            url: record.link.url,
                            frecencySortScore: record.destinationLink?.frecencyVisitSortScore ?? record.link.frecencyVisitSortScore,
                            destinationURL: record.destinationLink?.url
                        )
                    }
                completion(.success(results))
            } catch {
                Logger.shared.logError("history search failure: \(error)", category: .search)
                completion(.failure(error))
            }
        }
    }

    func deleteAll() throws {
        _ = try self.write { db in
            try Link.deleteAll(db)
        }
    }

    // MARK: - FrecencyUrlRecord

    func saveFrecencyUrl(_ frecencyUrl: FrecencyUrlRecord) throws {
        try self.write { db in
            try frecencyUrl.save(db)
        }
    }

    func save(urlFrecencies: [FrecencyUrlRecord]) throws {
        try self.write { db in
            for frecency in urlFrecencies {
                try frecency.save(db)
            }
        }
    }

    func fetchOneFrecency(fromUrl: UUID) throws -> [FrecencyParamKey: FrecencyUrlRecord] {
        var result = [FrecencyParamKey: FrecencyUrlRecord]()
        for type in FrecencyParamKey.allCases {
            try self.read { db in
                if let record = try FrecencyUrlRecord.fetchOne(db, sql: "SELECT * FROM FrecencyUrlRecord WHERE urlId = ? AND frecencyKey = ?", arguments: [fromUrl, type]) {
                    result[type] = record
                }
            }
        }

        return result
    }

    func getFrecencies(urlIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyUrlRecord] {
        var scores = [UUID: FrecencyUrlRecord]()
        try? self.read { db in
            return try FrecencyUrlRecord
                .filter(urlIds.contains(FrecencyUrlRecord.Columns.urlId))
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchCursor(db)
                .forEach { scores[$0.urlId] = $0 }
        }
        return scores
    }
    func getFrecencyScoreValues(urlIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: Float] {
        let scores = getFrecencies(urlIds: urlIds, paramKey: paramKey)
        return scores.mapValues { $0.frecencySortScore }
    }
    func clearUrlFrecencies() throws {
        _ = try self.write { db in
            try FrecencyUrlRecord.deleteAll(db)
        }
    }
}

extension BeamManagerOwner {
    var urlHistoryManager: UrlHistoryManager? {
        try? manager(UrlHistoryManager.self)
    }
}

extension BeamData {
    var urlHistoryManager: UrlHistoryManager? {
        AppData.shared.currentAccount?.urlHistoryManager
    }
}
