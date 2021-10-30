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
        case id, url, title, createdAt, updatedAt, deletedAt, previousChecksum
    }
}

// Fetching methods
extension Link: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        self.init(url: row[Columns.url],
                   title: row[Columns.title],
                   createdAt: row[Columns.createdAt],
                   updatedAt: row[Columns.updatedAt],
                   deletedAt: row[Columns.deletedAt],
                   previousChecksum: row[Columns.previousChecksum]
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
        container[Columns.previousChecksum] = previousChecksum
    }
}

extension Link: BeamObjectProtocol {
    static var beamObjectTypeName: String = "link"

    var beamObjectId: UUID {
        get {
            id
        }
        set {
            id = newValue
        }
    }

    public func copy() throws -> Link {
        Link(url: url, title: title, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, previousChecksum: previousChecksum)
    }
}

enum BeamLinkDBManagerError: Error, Equatable {
    case localLinkNotFound
}

public class BeamLinkDB: LinkManager, BeamObjectManagerDelegate {
    static let tableName = "Link"
    var dbPool: DatabasePool

    //swiftlint:disable:next function_body_length
    init(path: String) throws {
        let configuration = GRDB.Configuration()

        dbPool = try DatabasePool(path: path, configuration: configuration)

        var migrator = DatabaseMigrator()

        migrator.registerMigration("createLinkDB") { db in
            try db.create(table: BeamLinkDB.tableName, ifNotExists: true) { table in
                table.column("id", .text).notNull().primaryKey().unique(onConflict: .replace)
                table.column("url", .text).notNull().indexed().unique(onConflict: .replace)
                table.column("title", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }
        }

        try migrator.migrate(dbPool)
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] {
        var matchingLinks = [UUID: Link]()
        try? dbPool.read { db in
            try Link.filter(Column("url").like("%\(url)%"))
                .fetchAll(db)
                .forEach { matchingLinks[$0.id] = $0 }
        }
        return matchingLinks
    }

    public func getIdFor(link: String) -> UUID? {
        try? dbPool.read { db in
            try Link.filter(Column("url") == link).fetchOne(db)?.id
        }
    }

    public func store(link: Link, saveOnNetwork: Bool) throws {
        try store(links: [link], saveOnNetwork: saveOnNetwork)
    }

    public func store(links: [Link], saveOnNetwork: Bool) throws {
        try dbPool.write { db in
            for var link in links {
                try link.insert(db)
            }
        }

        if saveOnNetwork, AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            for link in links {
                try self.saveOnNetwork(link)
            }
        }
    }

    public func createIdFor(link url: String, title: String? = nil) -> UUID {
        var link = Link(url: url, title: title)
        _ = try? dbPool.write { db in
            try link.insert(db)
        }

        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            _ = try? self.saveOnNetwork(link)
        }
        return link.id
    }

    public func linkFor(id: UUID) -> Link? {
        try? dbPool.read { db in
            try Link.filter(Column("id") == id).fetchOne(db)
        }
    }

    public func visit(link url: String, title: String? = nil) {
        var link = Link(url: url, title: title)
        _ = try? dbPool.write { db in
            do {
                try link.update(db, columns: [Column("updateAt")])
            } catch {
                try link.insert(db)
            }
        }

        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            _ = try? self.saveOnNetwork(link)
        }
    }

    public func deleteAll() throws {
        _ = try dbPool.write { db in
            try Link.deleteAll(db)
        }
    }

    public var allLinks: [Link] {
        (try? dbPool.read { db in
            try? Link.fetchAll(db)
        }) ?? []
    }

    // MARK: Sync
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ links: [Link]) throws {
        try store(links: links, saveOnNetwork: false)
    }

    func allObjects(updatedSince: Date?) throws -> [Link] {
        guard let updatedSince = updatedSince
        else {
            return try dbPool.read { db in try Link.fetchAll(db) }
        }

        return try dbPool.read { db in
            try Link.filter(Column("updatedAt") < updatedSince).fetchAll(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [Link] {
        try dbPool.read { db in
            try Link.filter(keys: ids).fetchAll(db)
        }
    }

    func checksumsForIds(_ ids: [UUID]) throws -> [UUID: String] {
        let values: [(UUID, String)] = try fetchWithIds(ids).compactMap {
            guard let previousChecksum = $0.previousChecksum else { return nil }
            return ($0.beamObjectId, previousChecksum)
        }

        return Dictionary(uniqueKeysWithValues: values)
    }

    func saveAllOnNetwork(_ links: [Link], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        let localTimer = BeamDate.now

        try self.saveOnBeamObjectsAPI(links) { result in
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
    }

    private func saveOnNetwork(_ link: Link, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        let localTimer = BeamDate.now
        try saveOnBeamObjectAPI(link) { result in
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
    }

    func persistChecksum(_ objects: [Link]) throws {
        Logger.shared.logDebug("Saved \(objects.count) BeamObject checksums",
                               category: .linkNetwork)

        var links: [Link] = []
        for updateObject in objects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var link = linkFor(id: updateObject.beamObjectId) else {
                throw BeamLinkDBManagerError.localLinkNotFound
            }

            link.previousChecksum = updateObject.previousChecksum
            links.append(link)
        }
        try store(links: links, saveOnNetwork: false)
    }

    func manageConflict(_ object: Link,
                        _ remoteObject: Link) throws -> Link {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [Link]) throws {
        try store(links: objects, saveOnNetwork: false)
    }

}
