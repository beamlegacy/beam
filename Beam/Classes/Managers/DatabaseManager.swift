import Foundation
import PromiseKit
import Promises
import BeamCore

// swiftlint:disable file_length

public struct DatabaseStruct {
    var id: UUID
    var title: String
    let createdAt: Date
    let updatedAt: Date
    var deletedAt: Date?

    var uuidString: String {
        id.uuidString.lowercased()
    }
}

extension DatabaseStruct {
    init(database: Database) {
        self.id = database.id
        self.createdAt = database.created_at
        self.updatedAt = database.updated_at
        self.title = database.title
    }

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = BeamDate.now
        self.updatedAt = BeamDate.now
    }

    func asApiType() -> DatabaseAPIType {
        let result = DatabaseAPIType(database: self)
        return result
    }
}

extension DatabaseStruct: Equatable {
    static public func == (lhs: DatabaseStruct, rhs: DatabaseStruct) -> Bool {
        lhs.id == rhs.id
    }
}

extension DatabaseStruct: Hashable {

}

enum DatabaseManagerError: Error, Equatable {
    case operationCancelled
    case localDatabaseNotFound
}

class DatabaseManager {
    private var coreDataManager: CoreDataManager
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let saveDatabaseQueue = OperationQueue()
    private static var networkRequests: [UUID: APIRequest] = [:]
    private let backgroundQueue = DispatchQueue.global(qos: .background)
    private var saveDatabasePromiseCancels: [UUID: () -> Void] = [:]

    static var defaultDatabase: DatabaseStruct {
        get {
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            return context.performAndWait {
                // We look at a default database set by the user
                if let savedDatabaseId = Configuration.databaseId,
                   let databaseId = UUID(uuidString: savedDatabaseId),
                   let database = try? Database.fetchWithId(context, databaseId) {
                    return DatabaseStruct(database: database)
                }

                // Saved Database not found, or none has been set, going default.

                // TODO: loc
                let result = Database.fetchOrCreateWithTitle(context, "Default")

                if result.objectID.isTemporaryID {
                    do {
                        try saveContext(context: context)
                    } catch {
                        assert(false)
                        Logger.shared.logError(error.localizedDescription, category: .coredata)
                    }
                }

                return DatabaseStruct(database: result)
            }
        }
        set {
            guard newValue != defaultDatabase else { return }
            Configuration.databaseId = newValue.id.uuidString.lowercased()
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            context.performAndWait {
                do {
                    let database = try Database.fetchWithId(context, newValue.id)
                    database?.updated_at = BeamDate.now
                    try saveContext(context: context)
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .database)
                }
            }
            NotificationCenter.default.post(name: .defaultDatabaseUpdate, object: newValue)
        }
    }

    init(coreDataManager: CoreDataManager? = nil) {
        self.coreDataManager = coreDataManager ?? CoreDataManager.shared
        self.mainContext = self.coreDataManager.mainContext
        self.backgroundContext = self.coreDataManager.backgroundContext
        saveDatabaseQueue.maxConcurrentOperationCount = 1
    }

    static var savedCount = 0
    // MARK: -
    // MARK: NSManagedObjectContext saves
    @discardableResult
    static func saveContext(context: NSManagedObjectContext) throws -> Bool {
        guard context.hasChanges else {
            return false
        }

        savedCount += 1

        do {
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(savedCount)] CoreDataManager saved", category: .coredata)
            return true
        } catch let error as NSError {
            switch error.code {
            case 133021:
                // Constraint conflict
                Logger.shared.logError("Couldn't save context because of a constraint: \(error)", category: .coredata)
                logConstraintConflict(error)
            case 133020:
                // Saving a version of NSManagedObject which is outdated
                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)", category: .coredata)
                logMergeConflict(error)
            default:
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
            }

            throw error
        }
    }

    static private func logConstraintConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSConstraintConflict] else { return }

        for conflict in conflicts {
            let conflictingDatabases: [Database] = conflict.conflictingObjects.compactMap { database in
                return database as? Database
            }

            for database in conflictingDatabases {
                Logger.shared.logError("Conflicting \(database.id), title: \(database.title), database: \(database)",
                                       category: .coredata)
            }

            if let database = conflict.databaseObject as? Database {
                Logger.shared.logError("Existing database \(database.id), title: \(database.title), database: \(database)",
                                       category: .coredata)
            }
        }
    }

    static private func logMergeConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain, let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }

        for conflict in conflicts {
            let title = (conflict.sourceObject as? Database)?.title ?? ":( DB Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)", category: .coredata)
        }
    }

    private func checkValidations(_ context: NSManagedObjectContext, _ document: Database) throws {
        try checkDuplicateTitles(context, document)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ database: Database) throws {
        // If database is deleted, we don't need to check title uniqueness
        guard database.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@", database.title, database.id as CVarArg)

        if Database.countWithPredicate(context, predicate) > 0 {
            let errString = "Title is already used in another database"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DOCUMENT_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
        }
    }

    private func parseDatabase(_ database: Database) -> DatabaseStruct {
        return DatabaseStruct(id: database.id,
                              title: database.title,
                              createdAt: database.created_at,
                              updatedAt: database.updated_at,
                              deletedAt: database.deleted_at)
    }

    // MARK: -
    // MARK: loading
    func allDatabasesTitles() -> [String] {
        do {
            if Thread.isMainThread {
                return try Database.fetchAll(context: mainContext).map { $0.title }
            } else {
                let context = coreDataManager.persistentContainer.newBackgroundContext()
                return try context.performAndWait {
                    try Database.fetchAll(context: context).map { $0.title }
                }
            }
        } catch {
            return []
        }
    }

    func allDatabases() -> [DatabaseStruct] {
        do {
            if Thread.isMainThread {
                return try Database.fetchAll(context: mainContext).map { DatabaseStruct(database: $0) }
            } else {
                let context = coreDataManager.persistentContainer.newBackgroundContext()
                return try context.performAndWait {
                    try Database
                        .fetchAll(context: context)
                        .map { DatabaseStruct(database: $0) }
                }
            }
        } catch {
            return []
        }
    }

    // MARK: -
    // MARK: Count
    func documentsCountForDatabase(_ id: UUID) -> Int {
        Document.countWithPredicate(CoreDataManager.shared.mainContext, nil, id)
    }

    // MARK: -
    // MARK: Create
    func create(title: String) -> DatabaseStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DatabaseStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let database = Database.create(context, title: title)

            do {
                try self.checkValidations(context, database)

                result = self.parseDatabase(database)
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .coredata)
            }

            semaphore.signal()
        }

        semaphore.wait()

        return result
    }

    func fetchOrCreate(title: String) -> DatabaseStruct? {
        mainContext.performAndWait {
            do {
                let database = Database.fetchOrCreateWithTitle(mainContext, title)
                try self.checkValidations(mainContext, database)
                try Self.saveContext(context: mainContext)
                return self.parseDatabase(database)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .coredata)
            }

            return nil
        }
    }

    /// Update local coredata instance with data we fetched remotely
    private func updateDatabaseWithDatabaseAPIType(_ database: Database, _ databaseType: DatabaseAPIType) {
        database.title = databaseType.title ?? database.title
        database.created_at = databaseType.createdAt ?? database.created_at
        database.deleted_at = databaseType.deletedAt ?? database.deleted_at
    }
}

// MARK: -
// MARK: Foundation
extension DatabaseManager {
    // MARK: -
    // MARK: Deletes
    func deleteDatabase(_ database: DatabaseStruct, includedRemote: Bool = true, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let context = CoreDataManager.shared.mainContext
        guard let coredataDb = try? Database.fetchWithId(context, database.id) else {
            completion?(.failure(DatabaseManagerError.localDatabaseNotFound))
            return
        }

        do {
            try Document.deleteWithPredicate(context, NSPredicate(format: "database_id = %@",
                                                                  database.id as CVarArg))
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion?(.failure(error))
            return
        }
        coredataDb.delete(context)

        // Trigger updates for Advanced Settings
        NotificationCenter.default.post(name: .defaultDatabaseUpdate, object: DatabaseManager.defaultDatabase)

        guard includedRemote else {
            completion?(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let databaseRequest = DatabaseRequest()

        do {
            // Remotely, deleting a database will delete all related documents
            try databaseRequest.deleteDatabase(database.id.uuidString.lowercased()) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .database)
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion?(.failure(error))
        }
    }

    func deleteAllDatabases(includedRemote: Bool = true, completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        do {
            try Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            completion?(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let databaseRequest = DatabaseRequest()

        do {
            try databaseRequest.deleteAllDatabases { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .database)
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion?(.failure(error))
        }
    }

    // MARK: -
    // MARK: Bulk calls
    func syncDatabases(completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        uploadAllDatabases { result in
            if case .success(let success) = result, success == true {
                self.fetchDatabases(completion)
                return
            }

            completion?(result)
        }
    }

    func uploadAllDatabases(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            do {
                let databases = try Database.fetchAll(context: context)
                let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }
                let databaseRequest = DatabaseRequest()

                let result: Bool = try databaseRequest.saveDatabases(databasesArray)

                completion?(.success(result))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func fetchDatabases(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let databaseRequest = DatabaseRequest()

        do {
            try databaseRequest.fetchDatabases { result in
                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success(let databases):
                    self.coreDataManager.backgroundContext.performAndWait {
                        for database in databases {
                            guard let database_id = database.id, let databaseId = UUID(uuidString: database_id) else { continue }
                            let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext, databaseId)
                            self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                        }

                        do {
                            try Self.saveContext(context: self.coreDataManager.backgroundContext)
                        } catch {
                            completion?(.failure(error))
                        }
                    }
                    completion?(.success(true))
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    func saveDatabase(_ databaseStruct: DatabaseStruct,
                      _ networkSave: Bool = true,
                      _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil,
                      completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(databaseStruct.title)", category: .database)
        var blockOperation: BlockOperation!
        blockOperation = BlockOperation { [weak self] in
            guard let self = self else { return }

            // In case the operationqueue was cancelled way before this started
            if blockOperation.isCancelled {
                completion?(.failure(DatabaseManagerError.operationCancelled))
                return
            }
            let context = self.coreDataManager.backgroundContext

            context.performAndWait { [weak self] in
                guard let self = self else { return }

                if blockOperation.isCancelled {
                    completion?(.failure(DatabaseManagerError.operationCancelled))
                    return
                }

                let database = Database.fetchOrCreateWithId(context, databaseStruct.id)
                database.update(databaseStruct)

                do {
                    try self.checkValidations(context, database)
                } catch {
                    completion?(.failure(error))
                    return
                }

                if blockOperation.isCancelled {
                    completion?(.failure(DatabaseManagerError.operationCancelled))
                    return
                }

                do {
                    try Self.saveContext(context: context)
                } catch {
                    completion?(.failure(error))
                    return
                }

                completion?(.success(true))

                // If not authenticated, we don't need to send to BeamAPI
                if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled, networkSave {
                    // We want to fetch back the document, to update it's previousChecksum
                    //  context.refresh(document, mergeChanges: false)
                    guard let updatedDatabase = try? Database.fetchWithId(context, databaseStruct.id) else {
                        Logger.shared.logError("Weird, database disappeared: \(databaseStruct.id) \(databaseStruct.title)", category: .coredata)
                        return
                    }

                    let updatedDatabaseStruct = DatabaseStruct(database: updatedDatabase)
                    self.saveDatabaseStructOnAPI(updatedDatabaseStruct, networkCompletion)
                } else {
                    networkCompletion?(.failure(APIRequestError.notAuthenticated))
                }
            }

        }
        saveDatabaseQueue.addOperation(blockOperation)
    }

    @discardableResult
    internal func saveDatabaseStructOnAPI(_ databaseStruct: DatabaseStruct,
                                          _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return nil
        }

        guard databaseStruct.deletedAt == nil else {
            completion?(.success(false))
            return nil
        }

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        do {
            let databaseApiType = databaseStruct.asApiType()
            try databaseRequest.saveDatabase(databaseApiType) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .database)
                    completion?(.failure(error))
                case .success:
                    completion?(.success(true))
                }
            }
        } catch {
            completion?(.failure(error))
        }
        return nil
    }
}

// MARK: PromiseKit
extension DatabaseManager {
    // MARK: -
    // MARK: Deletes
    func deleteDatabase(_ database: DatabaseStruct, includedRemote: Bool = true) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        let databaseRequest = DatabaseRequest()

        return promise
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                try context.performAndWait {
                    guard let coreDataDatabase = try? Database.fetchWithId(context, database.id) else {
                        throw DatabaseManagerError.localDatabaseNotFound
                    }

                    try Document.deleteWithPredicate(context, NSPredicate(format: "database_id = %@",
                                                                          database.id as CVarArg))
                    coreDataDatabase.delete(context)

                    // Trigger updates for Advanced Settings
                    NotificationCenter.default.post(name: .defaultDatabaseUpdate, object: DatabaseManager.defaultDatabase)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled,
                          includedRemote else {
                        return .value(false)
                    }

                    let result: PromiseKit.Promise<DatabaseAPIType?> = databaseRequest.deleteDatabase(database.id.uuidString.lowercased())
                    return result.map(on: self.backgroundQueue) { _ in true }
                }
            }
    }

    func deleteAllDatabases(includedRemote: Bool = true) -> PromiseKit.Promise<Bool> {
        do {
            try Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            return Promise(error: error)
        }

        guard includedRemote else {
            return .value(true)
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }

        let databaseRequest = DatabaseRequest()

        let promise: PromiseKit.Promise<Bool> = databaseRequest.deleteAllDatabases()

        return promise
    }

    // MARK: -
    // MARK: Bulk calls
    func syncDatabases() -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<Bool> = uploadAllDatabases()

        return promise.then { result -> PromiseKit.Promise<Bool> in
            guard result == true else { return .value(result) }

            return self.fetchDatabases()
        }
    }

    func uploadAllDatabases() -> PromiseKit.Promise<Bool> {
        self.coreDataManager.background()
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<[DatabaseAPIType]> in
                try context.performAndWait {
                    let databaseRequest = DatabaseRequest()

                    let databases = try Database.fetchAll(context: context)
                    let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }

                    let saveDBPromise: PromiseKit.Promise<[DatabaseAPIType]> = databaseRequest.saveDatabases(databasesArray)

                    return saveDBPromise
                }
            }.map(on: backgroundQueue) { _ in true }
    }

    func fetchDatabases() -> PromiseKit.Promise<Bool> {
        let databaseRequest = DatabaseRequest()

        let promise: PromiseKit.Promise<[DatabaseAPIType]> = databaseRequest.fetchDatabases()

        return promise
            .then(on: backgroundQueue) { databases -> PromiseKit.Promise<Bool> in
                try self.coreDataManager.backgroundContext.performAndWait {
                    for database in databases {
                        guard let database_id = database.id, let databaseId = UUID(uuidString: database_id) else { continue }
                        let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext, databaseId)
                        self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                    }

                    try Self.saveContext(context: self.coreDataManager.backgroundContext)

                    return .value(true)
                }
            }
    }

    func saveDatabaseOnApi(_ databaseStruct: DatabaseStruct) -> PromiseKit.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }

        guard databaseStruct.deletedAt == nil else {
            return .value(false)
        }

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        let promise: PromiseKit.Promise<DatabaseAPIType> = databaseRequest.saveDatabase(databaseStruct.asApiType())

        return promise.map(on: backgroundQueue) { _ in true }
    }

    func saveDatabase(_ databaseStruct: DatabaseStruct) -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Guarantee<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false

        // Cancel previous promise
        saveDatabasePromiseCancels[databaseStruct.id]?()

        let result = promise
            .then(on: self.backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                Logger.shared.logDebug("Saving database \(databaseStruct.title)", category: .database)

                guard !cancelme else { throw PMKError.cancelled }

                return try context.performAndWait {
                    let database = Database.fetchOrCreateWithId(context, databaseStruct.id)
                    database.update(databaseStruct)

                    guard !cancelme else { throw PMKError.cancelled }
                    try Self.saveContext(context: context)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return .value(true)
                    }

                    context.refresh(database, mergeChanges: false)

                    let updatedDatabaseStruct = DatabaseStruct(database: database)
                    return self.saveDatabaseOnApi(updatedDatabaseStruct)
                }
            }.ensure {
                self.saveDatabasePromiseCancels[databaseStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDatabasePromiseCancels[databaseStruct.id] = cancel

        return result
    }
}

// MARK: Promises
extension DatabaseManager {
    // MARK: -
    // MARK: Deletes
    func deleteDatabase(_ database: DatabaseStruct, includedRemote: Bool = true) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<NSManagedObjectContext> = coreDataManager.background()
        let databaseRequest = DatabaseRequest()

        return promise
            .then(on: backgroundQueue) { context -> Promises.Promise<Bool> in
                try context.performAndWait {
                    guard let coreDataDatabase = try? Database.fetchWithId(context, database.id) else {
                        throw DatabaseManagerError.localDatabaseNotFound
                    }

                    try Document.deleteWithPredicate(context, NSPredicate(format: "database_id = %@",
                                                                          database.id as CVarArg))
                    coreDataDatabase.delete(context)

                    // Trigger updates for Advanced Settings
                    NotificationCenter.default.post(name: .defaultDatabaseUpdate, object: DatabaseManager.defaultDatabase)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled,
                          includedRemote else {
                        return Promise(false)
                    }

                    let result: Promises.Promise<DatabaseAPIType?> = databaseRequest.deleteDatabase(database.id.uuidString.lowercased())
                    return result.then(on: self.backgroundQueue) { _ in true }
                }
            }
    }

    func deleteAllDatabases(includedRemote: Bool = true) -> Promises.Promise<Bool> {
        do {
            try Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            return Promise(error)
        }

        guard includedRemote else {
            return Promise(true)
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }

        let databaseRequest = DatabaseRequest()

        let promise: Promises.Promise<Bool> = databaseRequest.deleteAllDatabases()

        return promise
    }

    // MARK: -
    // MARK: Bulk calls
    func syncDatabases() -> Promises.Promise<Bool> {
        let promise: Promises.Promise<Bool> = uploadAllDatabases()

        return promise.then { result -> Promises.Promise<Bool> in
            guard result == true else { return Promise(result) }

            return self.fetchDatabases()
        }
    }

    func uploadAllDatabases() -> Promises.Promise<Bool> {
        self.coreDataManager.background()
            .then(on: backgroundQueue) { context -> Promises.Promise<[DatabaseAPIType]> in
                try context.performAndWait {
                    let databaseRequest = DatabaseRequest()

                    let databases = try Database.fetchAll(context: context)
                    let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }

                    let saveDBPromise: Promises.Promise<[DatabaseAPIType]> = databaseRequest.saveDatabases(databasesArray)

                    return saveDBPromise
                }
            }.then(on: backgroundQueue) { _ in true }
    }

    func fetchDatabases() -> Promises.Promise<Bool> {
        let databaseRequest = DatabaseRequest()

        let promise: Promises.Promise<[DatabaseAPIType]> = databaseRequest.fetchDatabases()

        return promise
            .then(on: backgroundQueue) { databases -> Promises.Promise<Bool> in
                try self.coreDataManager.backgroundContext.performAndWait {
                    for database in databases {
                        guard let database_id = database.id, let databaseId = UUID(uuidString: database_id) else { continue }
                        let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext, databaseId)
                        self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                    }

                    try Self.saveContext(context: self.coreDataManager.backgroundContext)

                    return Promise(true)
                }
            }
    }

    func saveDatabaseOnApi(_ databaseStruct: DatabaseStruct) -> Promises.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }

        guard databaseStruct.deletedAt == nil else {
            return Promise(false)
        }

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        let promise: Promises.Promise<DatabaseAPIType> = databaseRequest.saveDatabase(databaseStruct.asApiType())

        return promise.then(on: backgroundQueue) { _ in true }
    }

    func saveDatabase(_ databaseStruct: DatabaseStruct) -> Promises.Promise<Bool> {
        let promise: Promises.Promise<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false

        // Cancel previous promise
        saveDatabasePromiseCancels[databaseStruct.id]?()

        let result = promise
            .then(on: self.backgroundQueue) { context -> Promises.Promise<Bool> in
                Logger.shared.logDebug("Saving database \(databaseStruct.title)", category: .database)

                guard !cancelme else { throw PMKError.cancelled }

                return try context.performAndWait {
                    let database = Database.fetchOrCreateWithId(context, databaseStruct.id)
                    database.update(databaseStruct)

                    guard !cancelme else { throw PMKError.cancelled }
                    try Self.saveContext(context: context)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return Promise(true)
                    }

                    context.refresh(database, mergeChanges: false)

                    let updatedDatabaseStruct = DatabaseStruct(database: database)
                    return self.saveDatabaseOnApi(updatedDatabaseStruct)
                }
            }.always {
                self.saveDatabasePromiseCancels[databaseStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDatabasePromiseCancels[databaseStruct.id] = cancel

        return result
    }
}

// swiftlint:enable file_length
