//
//  BeamLinkDB.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/10/2021.
//

import Foundation
import GRDB
import BeamCore

//public struct Link:
// SQL generation
extension Link: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, url, title, createdAt, updatedAt, deletedAt
    }
    static let frecencyScores = hasMany(FrecencyUrlRecord.self, using: ForeignKey(["urlId"]))
}

// Fetching methods
extension Link: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        self.init(url: row[Columns.url],
                  title: row[Columns.title],
                  createdAt: row[Columns.createdAt],
                  updatedAt: row[Columns.updatedAt],
                  deletedAt: row[Columns.deletedAt]
        )
    }
}

// Persistence methods
extension Link: MutablePersistableRecord {
    /// The values persisted in the database
    public static let persistenceConflictPolicy = PersistenceConflictPolicy(
            insert: .replace,
            update: .replace)

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.url] = url
        container[Columns.title] = title
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
    }
}

extension Link: BeamObjectProtocol {
    static var beamObjectType = BeamObjectObjectType.link

    var beamObjectId: UUID {
        get {
            id
        }
        set {
            id = newValue
        }
    }

    public func copy() throws -> Link {
        Link(url: url, title: title, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

enum BeamLinkDBManagerError: Error, Equatable {
    case localLinkNotFound
}

struct LinkWithFrecency: FetchableRecord {
    var link: Link
    var frecency: FrecencyUrlRecord?

    init(row: Row) {
        link = Link(row: row)
        frecency = row["frecency"]
    }
}

public class BeamLinkDB: LinkManager, BeamObjectManagerDelegate {
    let db: GRDBDatabase
    static let tableName = "Link"
    var dbPool: DatabasePool
    static var shared = BeamLinkDB(path: BeamData.linkDBPath)
    internal static var backgroundQueue = DispatchQueue(label: "Links BeamObjectManager backgroundQueue", qos: .userInitiated)

    //swiftlint:disable:next function_body_length
    init(path: String, db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db

    //TODO: remove everything dbPool related when link data moved to GRDB
        let configuration = GRDB.Configuration()
        do {
            dbPool = try DatabasePool(path: path, configuration: configuration)
        } catch {
            fatalError("Couldn't instanciate link db: \(error)")
        }
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createLinkDB") { db in
            try db.create(table: BeamLinkDB.tableName, ifNotExists: true) { table in
                table.column("id", .text).notNull().primaryKey().unique(onConflict: .replace)
                table.column("url", .text).notNull().indexed().unique(onConflict: .replace)
                table.column("title", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
            }
        }
        do {
            try migrator.migrate(dbPool)
        } catch {
            fatalError("Couldn't migrate link db: \(error)")
        }
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] {
        return db.getLinks(matchingUrl: url)
    }

    public func getOrCreateIdFor(url: String, title: String?) -> UUID {
        guard url != Link.missing.url else { return Link.missing.id }
        return db.getOrCreateIdFor(url: url, title: title)
    }

    private func store(link: Link, shouldSaveOnNetwork: Bool, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try store(links: [link], shouldSaveOnNetwork: shouldSaveOnNetwork, networkCompletion: networkCompletion)
    }

    private func store(links: [Link], shouldSaveOnNetwork: Bool, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try db.insert(links: links)

        guard shouldSaveOnNetwork else { return }
        saveOnNetwork(links, networkCompletion)
    }

    public func linkFor(id: UUID) -> Link? {
        db.linkFor(id: id)
        }

    public func isDomain(id: UUID) -> Bool {
        guard let link = linkFor(id: id), URL(string: link.url)?.isDomain ?? false else { return false }
        return true
    }

    public func getDomainId(id: UUID) -> UUID? {
        guard let link = linkFor(id: id),
              let domain = URL(string: link.url)?.domain else { return nil }
        return getOrCreateIdFor(url: domain.absoluteString, title: nil)
    }

    public func linkFor(url: String) -> Link? {
        db.linkFor(url: url)
    }

    public func visit(_ url: String, title: String? = nil) -> UUID {
        return visit(url, title: title).id
    }

    public func visit(_ url: String, title: String?) -> Link {
        guard url != Link.missing.url else { return Link.missing }
        let link: Link = db.visit(url: url, title: title)
        saveOnNetwork(link)
        return link
    }

    public func deleteAllLegacy() throws {
        _ = try dbPool.write { db in
            try Link.deleteAll(db)
        }
    }

    public func deleteAll() throws {
        try db.deleteAll()
    }

    public var allLinks: [Link] {
        return (try? db.allLinks(updatedSince: nil)) ?? []
    }

    public var allLinksLegacy: [Link] {
        (try? dbPool.read { db in
            try? Link.fetchAll(db)
        }) ?? []
    }

    public var countLegacy: Int? {
        return try? dbPool.read { db in
            try Link.fetchCount(db)
        }
    }
    public func showAllLinks() {
        Logger.shared.logDebug("------Links-------", category: .linkDB)
        for link in allLinks.sorted(by: { (lhs, rhs) in lhs.url < rhs.url }) {
            Logger.shared.logDebug("id: \(link.id) - url: \(link.url)", category: .linkDB)
        }
    }

    // MARK: Sync
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ links: [Link]) throws {
        try store(links: links, shouldSaveOnNetwork: false)
    }

    func allObjects(updatedSince: Date?) throws -> [Link] {
        return try db.allLinks(updatedSince: updatedSince)
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [Link] {
        return try db.getLinks(ids: ids)
    }

    func saveAllOnNetwork(_ links: [Link], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        let localTimer = BeamDate.now

        Self.backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectsAPI(links) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved \(links.count) links on the BeamObject API",
                                               category: .linkNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the links on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .linkNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    private func saveOnNetwork(_ links: [Link], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }

        let localTimer = BeamDate.now

        Logger.shared.logDebug("Will save links \(links) on the BeamObject API",
                               category: .linkNetwork)

        Self.backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectsAPI(links) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved links \(links) on the BeamObject API",
                                               category: .linkNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the link on the BeamObjects API with error: \(error.localizedDescription)",
                                               category: .linkNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    private func saveOnNetwork(_ link: Link, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }

        let localTimer = BeamDate.now

        Logger.shared.logDebug("Will save link \(link.url) [\(link.id)] on the BeamObject API",
                               category: .linkNetwork)

        let backgroundQueue = DispatchQueue(label: "Link BeamObjectManager backgroundQueue", qos: .userInitiated)

        backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectAPI(link) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved link \(link.url) [\(link.id)] on the BeamObject API",
                                               category: .linkNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the link on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .linkNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    func manageConflict(_ object: Link,
                        _ remoteObject: Link) throws -> Link {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [Link]) throws {
        try store(links: objects, shouldSaveOnNetwork: false)
    }

}
