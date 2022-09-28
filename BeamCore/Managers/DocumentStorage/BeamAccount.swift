//
//  Account.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2022.
//

import Foundation
import BeamCore
import GRDB
import Combine

public enum BeamAccountError: Error {
    case databaseDoesntExist
    case databaseAlreadyExists
}

public struct BeamDeletedAccount: Equatable, Hashable {
    var source: String
    var account: BeamAccount
    var id: UUID

    init(_ source: BeamDocumentSource, _ account: BeamAccount, _ id: UUID) {
        self.source = source.sourceId
        self.account = account
        self.id = id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(id)
    }

    static public func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source &&
        lhs.account === rhs.account
    }
}

/// An account contains the user's meta data (name, id, etc) as well as a set of document collections.
public class BeamAccount: ObservableObject, Equatable, Codable, BeamManagerOwner, BeamDocumentSource {
    @Published public private(set) var id: UUID
    @Published public private(set) var email: String
    @Published public private(set) var name: String

    @Published public private(set) var path: String = ""

    @Published public private(set) var databases: [UUID: BeamDatabase] = [:]
    @Published public private(set) var allDatabases: [BeamDatabase] = []

    private var synchronizationTask: Task<Bool, Error>?
    private var synchronizationSubject = PassthroughSubject<Bool, Never>()

    var isSynchronizationRunning: Bool { synchronizationTask != nil }

    var checkPrivateKeyTask:Task<Bool, Never>?

    var isSynchronizationRunningPublisher: AnyPublisher<Bool, Never> {
        synchronizationSubject.eraseToAnyPublisher()
    }

    public var objectManager: BeamObjectManager {
        data.objectManager
    }

    public var defaultDatabase: BeamDatabase {
        return getOrCreateDefaultDatabase()
    }

    public var grdbStore: GRDBStore!

    /// This publisher is triggered anytime we are completely removing a database
    static let accountDeleted = PassthroughSubject<BeamDeletedAccount, Never>()

    public static var sourceId: String { "\(Self.self)" }
    public var defaultDatabaseId: UUID = UUID.null

    public var managers = [UUID: BeamManager]()
    public static var registeredManagers = [BeamManager.Type]()

    let userSessionRequest = UserSessionRequest()
    let userInfoRequest = UserInfoRequest()

    public let data = BeamData.shared

    public internal(set) var signedIn = false

    /// Only use nil as a path for testing purposes
    public init(id: UUID, email: String, name: String, path: String?, overrideDatabasePath: String? = nil, migrate: Bool = true) throws {
        self.id = id
        self.name = name
        self.email = email
        self.path = path ?? ""

        if path != nil {
            try createPath()
            try setup(overrideDatabasePath: overrideDatabasePath, migrate: migrate)
        }
    }

    private func setup(overrideDatabasePath: String?, migrate: Bool) throws {
        let databasePath = URL(fileURLWithPath: path).appendingPathComponent("account.sqlite").path
        let db = try GRDBStore.createWriter(at: overrideDatabasePath ?? databasePath)
        grdbStore = GRDBStore(writer: db)

        try loadManagers(grdbStore)

        if migrate {
            try grdbStore.migrate()
        }

        try postMigrationSetup()

        try refreshDatabases()
        setupSync()

        DispatchQueue.main.async {
            do {
                try self.data.reindexFileReferences()
            } catch {
                Logger.shared.logError("Error while reindexing all file references: \(error)", category: .fileDB)
            }
        }
    }

    public func loadDatabase(_ id: UUID) throws -> BeamDatabase {
        guard let database = databases[id] else { throw BeamAccountError.databaseDoesntExist }
        if !database.isLoaded {
            try database.load()
        }
        return database
    }

    public func addDatabase(_ db: BeamDatabase) throws {
        guard databases[db.id] == nil else { throw BeamAccountError.databaseAlreadyExists }
        databases[db.id] = db
        db.account = self
        allDatabases = Array(databases.values)
    }

    /// Remove the database from the account, only in memory, don't remove the files from disk
    public func removeDatabase(_ id: UUID) throws {
        guard databases[id] != nil else { throw BeamAccountError.databaseDoesntExist }
        try unloadDatabase(id)
        databases.removeValue(forKey: id)
        allDatabases = Array(databases.values)
    }

    /// Remove the database from the account, in memory and from disk
    public func deleteDatabase(_ id: UUID) {
        guard let database = databases[id] else { return }
        do {
            try database.delete(self)
        } catch {
            Logger.shared.logError("Cannot delete database \(id): \(error)", category: .sync)
        }
        do {
            try removeDatabase(id)
        } catch {
            Logger.shared.logError("Cannot remove database \(id): \(error)", category: .sync)
        }
    }

    public func unloadDatabase(_ id: UUID) throws {
        guard let database = databases[id] else { throw BeamAccountError.databaseDoesntExist }
        try database.unload()
    }

    func setCurrentDatabase(_ database: BeamDatabase) throws {
        try data.setCurrentDatabase(database)
    }

    @discardableResult
    public func getOrCreateDefaultDatabase() -> BeamDatabase {
        if let database = databases[defaultDatabaseId] {
            return database
        }

        // There is no database, let's create one
        defaultDatabaseId = UUID()
        let database = BeamDatabase(account: self, id: defaultDatabaseId, name: "Default")
        databases[database.id] = database
        allDatabases = Array(databases.values)

        try? database.save(self)
        return database
    }

    // MARK: Equatable
    public static func == (lhs: BeamAccount, rhs: BeamAccount) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, email, name, defaultDatabaseId
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        defaultDatabaseId = try container.decode(UUID.self, forKey: .defaultDatabaseId)
    }

    deinit {
        do {
            try unload()
        } catch {
            Logger.shared.logError("Error while BeamAccount  \(self) deinit: \(error)", category: .accountManager)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(defaultDatabaseId, forKey: .defaultDatabaseId)
    }

    static func jsonUrlFrom(path: String) -> URL {
        let mainUrl = URL(fileURLWithPath: path)
        return mainUrl.appendingPathComponent("account.json")
    }

    var jsonUrl: URL {
        Self.jsonUrlFrom(path: path)
    }

    private func createPath() throws {
        if !FileManager.default.fileExists(atPath: path) {
            accountWillBeCreated()
        }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
    }

    func setupManagers() {
        
    }

    public func save() throws {
        try createPath()

        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let url = jsonUrl
        try data.write(to: url)

        for db in databases.values {
            do {
                try db.save(self)
            } catch {
                Logger.shared.logError("Unable to save BeamDatabase \(db.title) - \(db.id): Error", category: .database)
            }
        }
    }

    public func pathForDatabase(_ id: UUID) -> String {
        return URL(fileURLWithPath: path).appendingPathComponent("database-\(id)").path
    }

    public func refreshDatabases() throws {
        let urls = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for url in urls where url.hasDirectoryPath {
            do {
                let db = try BeamDatabase.load(fromFolder: url.path, inAccount: self)
                databases[db.id] = db
            } catch {
                Logger.shared.logError("Couldn't load BeamDatabase from \(url): \(error)", category: .database)
            }
        }
        allDatabases = Array(databases.values)
    }

    public static func load(fromFolder path: String, overrideDatabasePath: String? = nil, migrate: Bool = true) throws -> Self {
        let jsonUrl = jsonUrlFrom(path: path)
        let data = try Data(contentsOf: jsonUrl)
        let decoder = JSONDecoder()
        let account = try decoder.decode(Self.self, from: data)
        account.path = path

        try account.setup(overrideDatabasePath: overrideDatabasePath, migrate: migrate)
        try account.refreshDatabases()
        return account
    }

    func unload() throws {
        uninitSync()
        try allDatabases.forEach {
            try $0.unload()
        }
        allDatabases.removeAll()
        databases.removeAll()
        unloadManagers()
        if let store = grdbStore {
            store.close()
            self.grdbStore = nil
        }

        // Do not unregister objectManager managers here.
        // For every BeamAccount created (for example during the check for legacy data migration))
        // we create a temp instance of BeamAccount
        // When this instance is deallocated, the BeamObject manager will loose all existing registered managers
        
//        objectManager.unregisterAll()

    }

    func delete(_ source: BeamDocumentSource) throws {
        guard let grdbStore = grdbStore else { return }

        allDatabases.forEach {
            deleteDatabase($0.id)
        }

        unloadManagers()

        grdbStore.close()
        self.grdbStore = nil

        try FileManager.default.removeItem(atPath: path)
        Self.accountDeleted.send(BeamDeletedAccount(source, self, id))
    }

    // MARK: Sync
    var databaseSynchroniser: BeamDatabaseSynchronizer?
    var documentSynchroniser: BeamDocumentSynchronizer?

    public static func disableSync() {
        syncDisabled = true
    }

    public static func enableSync() {
        syncDisabled = false
    }

    var syncSetup = false
    private static var syncDisabled = false
    public func setupSync() {
        guard !syncSetup, !Self.syncDisabled else { return }
        databaseSynchroniser = BeamDatabaseSynchronizer(account: self, objectManager: objectManager)
        documentSynchroniser = BeamDocumentSynchronizer(account: self, objectManager: objectManager)
        data.registerSyncDelegates()
        syncSetup = true
    }

    private func uninitSync() {
        databaseSynchroniser = nil
        documentSynchroniser = nil
        syncSetup = false
    }

    func clear() {
        databases.values.forEach { $0.clear() }
        clearManagersDB()
    }

    private func accountWillBeCreated() {
        Persistence.Sync.BeamObjects.last_received_at = nil
        Persistence.Sync.BeamObjects.last_updated_at = nil
    }

    public func checkAndRepairIntegrity() {
        grdbStore.checkAndRepairIntegrity()
        for database in allDatabases where database.isLoaded {
            database.checkAndRepairIntegrity()
        }
    }

    static func loadAccounts(from url: URL, stopAtFirst: Bool = false) -> [BeamAccount] {
        guard let urls = try? FileManager().contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            Logger.shared.logError("Unable to finds potential accounts from \(url)", category: .accountManager)
            return []
        }
        var first = true
        return urls.compactMap { url -> BeamAccount? in
            do {
                if !first && stopAtFirst {
                    return nil
                }
                let account = try Self.load(fromFolder: url.path)
                first = false
                return account
            } catch {
                Logger.shared.logError("Unable to load account from \(url): \(error)", category: .accountManager)
                return nil
            }
        }
    }

    static func hasValidAccount(in url: URL) -> Bool {
        !loadAccounts(from: url, stopAtFirst: true).isEmpty
    }

    // MARK: - Private Key Check
    @MainActor
    func checkPrivateKey() async {
        if await checkPrivateKey(useBuiltinPrivateKeyUI: true) {
            objectManager.liveSync { (_, _) in
                Task { @MainActor in
                    do {
                        _ = try await self.syncDataWithBeamObject()
                    } catch {
                        Logger.shared.logError("Error while syncing data: \(error)", category: .document)
                    }
                    self.data.updateNoteCount()
                }
            }
        }
    }

    // MARK: - Web sockets
    func disconnectWebSockets() {
        objectManager.disconnectLiveSync()
    }

    // MARK: - Database
    @MainActor
    func syncDataWithBeamObject(force: Bool = false, showAlert: Bool = true) async throws -> Bool {
        let isRunningUnitTests = Configuration.env == .test && !ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument)
        guard !isRunningUnitTests,
              AuthenticationManager.shared.isAuthenticated,
              NetworkMonitor.isNetworkAvailable else {
            return false
        }

        if let task = synchronizationTask {
            Logger.shared.logDebug("syncTask already running", category: .beamObjectNetwork)
            return try await task.value
        }

        let task = launchSynchronizationTask(force, showAlert)

        synchronizationTask = task
        synchronizationIsRunningDidUpdate()

        return try await task.value
    }

    private func launchSynchronizationTask(_ force: Bool, _ showAlert: Bool) -> Task<Bool, Error> {
        Task { @MainActor in
            let localTimer = Date()
            let initialDBs = Set(allDatabases)
            Logger.shared.logInfo("syncAllFromAPI calling", category: .sync)
            do {
                try await objectManager.syncAllFromAPI(force: force, prepareBeforeSaveAll: {
                    self.mergeAllDatabases(initialDBs: initialDBs)
                })
            } catch {
                Logger.shared.logInfo("syncAllFromAPI failed: \(error)",
                                      category: .sync,
                                      localTimer: localTimer)
                self.synchronizationTaskDidStop()
                throw error
            }

            Logger.shared.logInfo("syncAllFromAPI called",
                                  category: .sync,
                                  localTimer: localTimer)
            self.synchronizationTaskDidStop()
            return true
        }
    }

    public func stopSynchronization() {
        if let task = synchronizationTask {
            task.cancel()
        }
    }

    @MainActor
    private func synchronizationTaskDidStop() {
        Logger.shared.logInfo("synchronizationTaskDidStop", category: .beamObjectNetwork)
        synchronizationTask = nil
        synchronizationIsRunningDidUpdate()
    }

    private func synchronizationIsRunningDidUpdate() {
        synchronizationSubject.send(isSynchronizationRunning)
    }

    private func indexAllNotes() {
        DispatchQueue.main.async {
            BeamNote.indexAllNotes(interactive: false)
        }
    }

    private func deleteEmptyDatabases(showAlert: Bool = true,
                                      _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        do {
            try deleteEmptyDatabases()
            completionHandler?(.success(true))
        } catch {
            Logger.shared.logInfo("deleteEmptyDatabases failed: \(error)", category: .database)
            completionHandler?(.failure(error))
        }
    }
}


extension BeamAccount {
    var fileDBManager: BeamFileDBManager? {
        data.currentDatabase?.fileDBManager
    }
}
