//
//  BeamDatabase.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2022.
//

import Foundation
import GRDB
import BeamCore
import Combine

enum BeamDatabaseError: Error {
    case managerNotFound

    /// This database can't be "auto" saved because it isn't parth of an account
    case missingAccount
}

public struct BeamDeletedDatabase: Equatable, Hashable {
    var source: String
    var account: BeamAccount
    var id: UUID
    var database: BeamDatabase

    init(_ source: BeamDocumentSource, _ account: BeamAccount, _ id: UUID, _ database: BeamDatabase) {
        self.source = source.sourceId
        self.account = account
        self.id = id
        self.database = database
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(account.id)
        hasher.combine(id)
    }

    static public func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source &&
        lhs.id == rhs.id &&
        lhs.account === rhs.account
    }
}

public class BeamDatabase: CustomStringConvertible, Codable, Identifiable, Equatable, Hashable, BeamManagerOwner, BeamOwner {
    weak public var account: BeamAccount?
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var source: String

    var grdbStore: GRDBStore!

    public var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }

    /// This publisher is triggered anytime we store a database
    static let databaseSaved = PassthroughSubject<BeamDatabase, Never>()
    /// This publisher is triggered anytime we are completely removing a database
    static let databaseDeleted = PassthroughSubject<BeamDeletedDatabase, Never>()

    public static var registeredManagers = [BeamManager.Type]()
    public var managers = [UUID: BeamManager]()

    enum CodingKeys: CodingKey {
        case id, title, createdAt, updatedAt, deletedAt, source
    }

    init(account: BeamAccount, id: UUID, name: String) {
        self.account = account
        self.id = id
        self.title = name
        self.createdAt = BeamDate.now
        self.updatedAt = BeamDate.now
        self.source = account.sourceId
    }

    required init(database: BeamDatabase) {
        self.account = database.account
        self.id = database.id
        self.title = database.title
        self.createdAt = database.createdAt
        self.updatedAt = database.updatedAt
        self.deletedAt = database.deletedAt
        self.source = database.source
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let syncDatabaseId = decoder.userInfo[BeamObject.beamObjectId] as? UUID ?? UUID.null

        id = (try container.decodeIfPresent(UUID.self, forKey: .id)) ?? syncDatabaseId
        source = (try container.decodeIfPresent(String.self, forKey: .source)) ?? "decoder"

        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let syncCoding = encoder.userInfo[BeamObject.beamObjectCoding] as? Bool ?? false

        if !syncCoding {
            try container.encode(id, forKey: .id)
            try container.encode(source, forKey: .source)
        }

        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    func load(overrideDatabasePath: String? = nil, migrate: Bool = true) throws {
        guard collection == nil else { return }
        guard let databasePath = account?.pathForDatabase(id)  else { throw BeamDocumentCollectionError.noAccount }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: databasePath), withIntermediateDirectories: true)
        let collectionPath = databasePath + "/data.sqlite"
        let db = try DatabaseQueue(path: overrideDatabasePath ?? collectionPath)
        grdbStore = GRDBStore(writer: db)

        try loadManagers(grdbStore)
        if migrate {
            try grdbStore.migrate()
        }
        try postMigrationSetup()
    }

    func unload() throws {
        for manager in managers.values {
            do {
                try manager.unload()
            } catch {
                Logger.shared.logError("Unable to unload manager \(manager) from \(self)", category: .database)
            }
        }
        unloadManagers()
    }

    private func createPath() throws {
        guard let account = account else {
            throw BeamDatabaseError.missingAccount
        }

        try FileManager.default.createDirectory(at: URL(fileURLWithPath: account.pathForDatabase(id)), withIntermediateDirectories: true)
    }

    public func save(_ source: BeamDocumentSource) throws {
        guard let account = account else {
            throw BeamDatabaseError.missingAccount
        }
        let path = account.pathForDatabase(id)
        try createPath()

        let encoder = JSONEncoder()
        self.source = source.sourceId
        let data = try encoder.encode(self)
        let url = Self.jsonUrlFrom(path: path)
        try data.write(to: url)

        Self.databaseSaved.send(self)
    }

    static func jsonUrlFrom(path: String) -> URL {
        let mainUrl = URL(fileURLWithPath: path)
        return mainUrl.appendingPathComponent("database.json")
    }

    static func load(fromFolder path: String, inAccount account: BeamAccount?) throws -> BeamDatabase {
        let url  = jsonUrlFrom(path: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let database = try decoder.decode(Self.self, from: data )
        database.account = account
        return database

    }

    func delete(_ source: BeamDocumentSource) throws {
        guard let grdbStore = grdbStore else { return }

        guard let account = account else {
            throw BeamDatabaseError.missingAccount
        }

        try grdbStore.writer.close()
        self.grdbStore = nil

        try FileManager.default.removeItem(atPath: account.pathForDatabase(id))
        Self.databaseDeleted.send(BeamDeletedDatabase(source, account, id, self))
    }

    public static func == (lhs: BeamDatabase, rhs: BeamDatabase) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(deletedAt)
        hasher.combine(source)
    }

    public func copy() throws -> Self {
        Self(database: self)
    }

    public func checkAndRepairIntegrity() {
        grdbStore.checkAndRepairIntegrity()
    }

    public func clear() {
        clearManagersDB()
    }

    public var description: String { "Database \(title) - \(id)" }
}

// MARK: -
// MARK: Helpers

extension BeamDatabase {
    func documentsCount() -> Int {
        do {
            if let collection = self.collection {
                return try collection.count()
            } else {
                Logger.shared.logError("Unable to get collection for \(self)", category: .database)
            }
        } catch {
            Logger.shared.logError("Unable to get document count for \(self)", category: .database)
        }
        return 0
    }

    func filesCount() -> Int {
        do {
            if let fileDBManager = self.fileDBManager {
                return try fileDBManager.fileCount()
            } else {
                Logger.shared.logError("Unable to get fileDBManager for \(self)", category: .database)
            }
        } catch {
            Logger.shared.logError("Unable to get file count for \(self)", category: .database)
        }
        return 0
    }

    func recordsCount() -> Int {
        return documentsCount() + filesCount()
    }
}

extension BeamDatabase {
    var previousChecksum: String? {
        BeamObjectChecksum.previousChecksum(object: self)
    }

    var hasBeenSyncedOnce: Bool {
        previousChecksum != nil
    }
}
