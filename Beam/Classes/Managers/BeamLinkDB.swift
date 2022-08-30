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
        case id, url, title, content, destination, createdAt, updatedAt, deletedAt, frecencyVisitLastAccessAt, frecencyVisitScore, frecencyVisitSortScore
    }

    static let frecencyForeign = "frecency"
    static let frecency = hasOne(FrecencyUrlRecord.self,
                                 key: frecencyForeign,
                                 using: ForeignKey([FrecencyUrlRecord.Columns.urlId], to: [Columns.id]))
    static let destinationLink = belongsTo(Link.self, key: "destinationLink", using: ForeignKey(["destination"], to: ["id"]))
}

// Fetching methods
extension Link: Identifiable, FetchableRecord {
    /// Creates a record from a database row
    public init(row: Row) {
        self.init(url: row[Columns.url],
                  title: row[Columns.title],
                  content: row[Columns.content],
                  destination: row[Columns.destination],
                  frecencyVisitLastAccessAt: row[Columns.frecencyVisitLastAccessAt],
                  frecencyVisitScore: row[Columns.frecencyVisitScore],
                  frecencyVisitSortScore: row[Columns.frecencyVisitSortScore],
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
        container[Columns.frecencyVisitLastAccessAt] = frecencyVisitLastAccessAt
        container[Columns.frecencyVisitScore] = frecencyVisitScore
        container[Columns.frecencyVisitSortScore] = frecencyVisitSortScore
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
        Link(url: url, title: title, content: "", frecencyVisitLastAccessAt: frecencyVisitLastAccessAt,
             frecencyVisitScore: frecencyVisitScore, frecencyVisitSortScore: frecencyVisitSortScore,
             createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
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

public class BeamLinkDB: LinkManagerProtocol, BeamObjectManagerDelegate {
    let objectManager: BeamObjectManager

    var changedObjects: [UUID : Link] = [:]
    let objectQueue = BeamObjectQueue<Link>()
    
    static let tableName = "link"
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }

    private var overridenManager: UrlHistoryManager?
    private var manager: UrlHistoryManager? {
        overridenManager ?? BeamData.shared.urlHistoryManager
    }

    init(objectManager: BeamObjectManager, overridenManager: UrlHistoryManager? = nil) {
        self.objectManager = objectManager
        self.overridenManager = overridenManager

        registerOnBeamObjectManager(objectManager)
    }

    public func getLinks(matchingUrl url: String) -> [UUID: Link] {
        return manager?.getLinks(matchingUrl: url) ?? [:]
    }
    public func getLinks(for ids: [UUID]) -> [UUID: Link] {
        do {
            return try manager?.getLinks(ids: ids) ?? [:]
        } catch {
            Logger.shared.logError("Couldn't get links: \(error)", category: .linkDB)
            return [UUID: Link]()
        }
    }
    public func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID {
        return manager?.getOrCreateId(for: url, title: title, content: content, destination: destination) ?? UUID.null
    }

    private func store(link: Link, shouldSaveOnNetwork: Bool, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try store(links: [link], shouldSaveOnNetwork: shouldSaveOnNetwork, networkCompletion: networkCompletion)
    }

    private func store(links: [Link], shouldSaveOnNetwork: Bool, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try manager?.insert(links: links)

        guard shouldSaveOnNetwork else { return }
        saveOnNetwork(links, networkCompletion)
    }

    public func linkFor(id: UUID) -> Link? {
        manager?.linkFor(id: id)
    }

    public func isDomain(id: UUID) -> Bool {
        guard let link = linkFor(id: id), URL(string: link.url)?.isDomain ?? false else { return false }
        return true
    }

    public func getDomainId(id: UUID) -> UUID? {
        guard let link = linkFor(id: id),
              let domain = URL(string: link.url)?.domain else { return nil }
        return getOrCreateId(for: domain.absoluteString, title: nil, content: nil, destination: nil)
    }

    public func linkFor(url: String) -> Link? {
        manager?.linkFor(url: url)
    }
    public func insertOrIgnore(links: [Link]) {
        do {
            try manager?.insertOrIgnore(links: links)
        } catch {
            Logger.shared.logError("Couldn't insert links: \(error)", category: .linkDB)
        }
    }

    @discardableResult
    public func visitId(_ url: String, title: String? = nil, content: String? = nil, destination: String? = nil) -> UUID {
        return visit(url, title: title, content: content, destination: destination).id
    }

    @discardableResult
    public func visit(_ url: String, title: String?, content: String?, destination: String?) -> Link {
        guard let link: Link = manager?.visit(url: url, title: title, content: content, destination: destination) else { return Link(url: url, title: title, content: content) }
        saveOnNetwork(link)
        return link
    }

    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try manager?.deleteAll()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                Task {
                    do {
                        try await self.deleteAllFromBeamObjectAPI()
                        networkCompletion?(.success(true))
                    } catch {
                        Logger.shared.logError("Error while deleting all contacts: \(error)", category: .contactsDB)
                        networkCompletion?(.success(false))
                    }
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

    public func updateFrecency(id: UUID, lastAccessAt: Date, score: Float, sortScore: Float) {
        manager?.updateLinkFrecency(id: id, lastAccessAt: lastAccessAt, score: score, sortScore: sortScore)
    }

    public func updateFrecencies(scores: [FrecencyScore]) {
        manager?.updateLinkFrecencies(scores: scores)
    }

    public var allLinks: [Link] {
        return (try? manager?.allLinks(updatedSince: nil)) ?? []
    }

    public func showAllLinks() {
        Logger.shared.logDebug("------Links-------", category: .linkDB)
        for link in allLinks.sorted(by: { (lhs, rhs) in lhs.url < rhs.url }) {
            Logger.shared.logDebug("id: \(link.id) - url: \(link.url)", category: .linkDB)
        }
    }

    // MARK: Sync
    static var conflictPolicy: BeamObjectConflictResolution = .fetchRemoteAndError

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ links: [Link]) throws {
        let ids = links.map { $0.id }
        let existingLinks: [UUID: Link] = (try? manager?.getLinks(ids: ids)) ?? [UUID: Link]()
        let linksToStore = links.map { (link) -> Link in
            var newLink = link
            //if received frecency fields are nil and local links exist, dont overwrite existing fields.
            newLink.frecencyVisitScore = link.frecencyVisitScore ?? existingLinks[link.id]?.frecencyVisitScore
            newLink.frecencyVisitSortScore = link.frecencyVisitSortScore ?? existingLinks[link.id]?.frecencyVisitSortScore
            newLink.frecencyVisitLastAccessAt = link.frecencyVisitLastAccessAt ?? existingLinks[link.id]?.frecencyVisitLastAccessAt
            return newLink
        }
        try store(links: linksToStore, shouldSaveOnNetwork: false)
    }

    func allObjects(updatedSince: Date?) throws -> [Link] {
        return try manager?.allLinks(updatedSince: updatedSince) ?? []
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [Link] {
        return try manager?.getLinks(ids: ids) ?? []
    }

    func saveAllOnNetwork(_ links: [Link], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let localTimer = Date()
                try await saveOnBeamObjectsAPI(links)
                Logger.shared.logDebug("Saved \(links.count) links on the BeamObject API",
                                       category: .linkNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the links on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .linkNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ links: [Link], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }

        Logger.shared.logDebug("Will save links \(links) on the BeamObject API",
                               category: .linkNetwork)

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let localTimer = Date()
                try await saveOnBeamObjectsAPI(links)
                Logger.shared.logDebug("Saved links \(links) on the BeamObject API",
                                       category: .linkNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the link on the BeamObjects API with error: \(error.localizedDescription)",
                                       category: .linkNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ link: Link, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }

        Logger.shared.logDebug("Will save link \(link.url) [\(link.id)] on the BeamObject API",
                               category: .linkNetwork)
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let localTimer = Date()

                try await saveOnBeamObjectAPI(link)
                Logger.shared.logDebug("Saved link \(link.url) [\(link.id)] on the BeamObject API",
                                       category: .linkNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the link on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .linkNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    func manageConflict(_ object: Link,
                        _ remoteObject: Link) throws -> Link {
        var result = object
        if remoteObject.updatedAt > object.updatedAt {
            result = remoteObject
        }
        result.frecencyVisitScore = remoteObject.frecencyVisitScore ?? object.frecencyVisitScore
        result.frecencyVisitSortScore = remoteObject.frecencyVisitSortScore ?? object.frecencyVisitSortScore
        result.frecencyVisitLastAccessAt = remoteObject.frecencyVisitLastAccessAt ?? object.frecencyVisitLastAccessAt
        return result
    }

    func saveObjectsAfterConflict(_ objects: [Link]) throws {
        try store(links: objects, shouldSaveOnNetwork: false)
    }
}
