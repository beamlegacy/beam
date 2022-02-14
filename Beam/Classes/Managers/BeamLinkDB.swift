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
        case id, url, title, content, destination, createdAt, updatedAt, deletedAt
    }

    static let frecencyForeign = "frecency"
    static let frecency = hasOne(FrecencyUrlRecord.self,
                                 key: frecencyForeign,
                                 using: ForeignKey([FrecencyUrlRecord.Columns.urlId], to: [Columns.id]))
}

// Fetching methods
extension Link: FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        self.init(url: row[Columns.url],
                  title: row[Columns.title],
                  content: row[Columns.content],
                  destination: row[Columns.destination],
                  createdAt: row[Columns.createdAt],
                  updatedAt: row[Columns.updatedAt],
                  deletedAt: row[Columns.deletedAt]
        )
    }
}

extension Link {
    struct FTS: TableRecord {
        static let databaseTableName = "linkContent"
    }

    // Association to perform a key join on both `rowid` columns.
    static let contentAssociation = hasOne(FTS.self, using: ForeignKey(["rowid"], to: ["rowid"]))
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
        container[Columns.content] = content
        container[Columns.destination] = destination
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
        Link(url: url, title: title, content: "", createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

extension Link: Equatable {
    static public func == (lhs: Link, rhs: Link) -> Bool {
        lhs.id == rhs.id
    }
}

extension Link: Hashable {
    public func hash(into hasher: inout Hasher) {
       hasher.combine(id)
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
    static var shared = BeamLinkDB()
    internal static var backgroundQueue = DispatchQueue(label: "Links BeamObjectManager backgroundQueue", qos: .userInitiated)

    //swiftlint:disable:next function_body_length
    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] {
        return db.getLinks(matchingUrl: url)
    }

    public func getOrCreateIdFor(url: String, title: String?, content: String?, destination: String?) -> UUID {
        guard url != Link.missing.url else { return Link.missing.id }
        return db.getOrCreateIdFor(url: url, title: title, content: content, destination: destination)
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
        return getOrCreateIdFor(url: domain.absoluteString, title: nil, content: nil, destination: nil)
    }

    public func linkFor(url: String) -> Link? {
        db.linkFor(url: url)
    }

    @discardableResult
    public func visitId(_ url: String, title: String? = nil, content: String? = nil, destination: String? = nil) -> UUID {
        return visit(url, title: title, content: content, destination: destination).id
    }

    @discardableResult
    public func visit(_ url: String, title: String?, content: String?, destination: String?) -> Link {
        guard url != Link.missing.url else { return Link.missing }
        let link: Link = db.visit(url: url, title: title, content: content, destination: destination)
        saveOnNetwork(link)
        return link
    }

    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try db.deleteAll()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                try self.deleteAllFromBeamObjectAPI { result in
                    networkCompletion?(result)
                }
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .linkNetwork)
        }
        networkCompletion?(.success(false))
    }

    public var allLinks: [Link] {
        return (try? db.allLinks(updatedSince: nil)) ?? []
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
                Logger.shared.logError(error.localizedDescription, category: .linkNetwork)
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
                Logger.shared.logError(error.localizedDescription, category: .linkNetwork)
            }
        }
    }

    private func saveOnNetwork(_ link: Link, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }

        let localTimer = BeamDate.now

        Logger.shared.logDebug("Will save link \(link.url) [\(link.id)] on the BeamObject API",
                               category: .linkNetwork)
        Self.backgroundQueue.async { [weak self] in
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
                Logger.shared.logError(error.localizedDescription, category: .linkNetwork)
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
