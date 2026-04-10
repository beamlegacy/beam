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
extension Link: @retroactive TableRecord {
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
extension Link: @retroactive Identifiable, @retroactive FetchableRecord {
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
extension Link: @retroactive MutablePersistableRecord {
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

extension Link: @retroactive Equatable {
    static public func == (lhs: Link, rhs: Link) -> Bool {
        lhs.id == rhs.id
    }
}

extension Link: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
       hasher.combine(id)
    }
}

extension Link {
    public static func aliasCleanup(_ db: GRDB.Database, query: SQLRequest<Link>, resetFrecency: Bool = false) throws {
        let now = BeamDate.now
        let aliases = try Self.fetchAll(db, query)
        for var alias in aliases {
            alias.destination = nil
            alias.updatedAt = now
            if resetFrecency {
                alias.frecencyVisitLastAccessAt = nil
                alias.frecencyVisitScore = nil
                alias.frecencyVisitSortScore = nil
            }
            try alias.save(db)
        }
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

public class BeamLinkDB: LinkManagerProtocol {
    static let tableName = "link"

    private var overridenManager: LinksDBManager?
    private var manager: LinksDBManager? {
        overridenManager ?? BeamData.shared.linksDBManager
    }

    init(overridenManager: LinksDBManager? = nil) {
        self.overridenManager = overridenManager
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

    private func store(link: Link) throws {
        try store(links: [link])
    }

    private func store(links: [Link]) throws {
        try manager?.insert(links: links)
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
        return link
    }

    public func deleteAll() {
        do {
            try manager?.deleteAll()
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .linkNetwork)
        }
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

    func fetchWithIds(_ ids: [UUID], includeDeleted: Bool = false) throws -> [Link] {
        return try manager?.getLinks(ids: ids, includeDeleted: includeDeleted) ?? []
    }
}
