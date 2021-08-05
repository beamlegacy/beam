import Foundation
import PromiseKit
import Promises
import BeamCore

// swiftlint:disable file_length

enum DatabaseManagerError: Error, Equatable {
    case operationCancelled
    case localDatabaseNotFound
    case titleAlreadyExists
}

extension DatabaseManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .operationCancelled:
            return "operation cancelled"
        case .localDatabaseNotFound:
            return "local Database Not Found"
        case .titleAlreadyExists:
            return "Title already exists"
        }
    }
}

class DatabaseManager {
    private var coreDataManager: CoreDataManager
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let saveDatabaseQueue = OperationQueue()
    private static var networkRequests: [UUID: APIRequest] = [:]
    private static var networkTasks: [UUID: URLSessionTask] = [:]
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
                Logger.shared.logError("Couldn't save context because the object is outdated and more recent in CoreData: \(error)",
                                       category: .coredata)
                logMergeConflict(error)
            default:
                Logger.shared.logError("Couldn't save context: \(error)", category: .coredata)
            }

            throw error
        }
    }

    static private func logConstraintConflict(_ error: NSError) {
        guard error.domain == NSCocoaErrorDomain,
              let conflicts = error.userInfo["conflictList"] as? [NSConstraintConflict] else { return }

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
        guard error.domain == NSCocoaErrorDomain,
              let conflicts = error.userInfo["conflictList"] as? [NSMergeConflict] else { return }

        for conflict in conflicts {
            let title = (conflict.sourceObject as? Database)?.title ?? ":( DB Not found"
            Logger.shared.logError("Old version: \(conflict.oldVersionNumber), new version: \(conflict.newVersionNumber), title: \(title)",
                                   category: .coredata)
        }
    }

    private func checkValidations(_ context: NSManagedObjectContext, _ database: Database) throws {
        try checkDuplicateTitles(context, database)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ database: Database) throws {
        // If database is deleted, we don't need to check title uniqueness
        guard database.deleted_at == nil else { return }

        let predicate = NSPredicate(format: "title = %@ AND id != %@", database.title, database.id as CVarArg)

        if Database.countWithPredicate(context, predicate) > 0 {
            let errString = "Title is already used in another database"
            let userInfo: [String: Any] = [NSLocalizedFailureReasonErrorKey: errString, NSValidationObjectErrorKey: self]
            throw NSError(domain: "DATABASE_ERROR_DOMAIN", code: 1001, userInfo: userInfo)
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
    func allTitles() -> [String] {
        do {
            if Thread.isMainThread {
                return try Database.fetchAll(mainContext).map { $0.title }
            } else {
                let context = coreDataManager.persistentContainer.newBackgroundContext()
                return try context.performAndWait {
                    try Database.fetchAll(context).map { $0.title }
                }
            }
        } catch {
            return []
        }
    }

    func all() -> [DatabaseStruct] {
        do {
            if Thread.isMainThread {
                return try Database.fetchAll(mainContext).map { DatabaseStruct(database: $0) }
            } else {
                let context = coreDataManager.persistentContainer.newBackgroundContext()
                return try context.performAndWait {
                    try Database
                        .fetchAll(context)
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

    private func isEqual(_ database: Database, to databaseStruct: DatabaseStruct) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        database.updated_at.intValue == databaseStruct.updatedAt.intValue &&
            database.created_at.intValue == databaseStruct.createdAt.intValue &&
            database.title == databaseStruct.title &&
            database.deleted_at?.intValue == databaseStruct.deletedAt?.intValue &&
            database.id == databaseStruct.id
    }

    private func isEqual(_ database: Database, to databaseType: DatabaseAPIType) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        database.updated_at.intValue == databaseType.updatedAt?.intValue &&
            database.created_at.intValue == databaseType.createdAt?.intValue &&
            database.title == databaseType.title &&
            database.deleted_at?.intValue == databaseType.deletedAt?.intValue &&
            database.id.uuidString.lowercased() == databaseType.id
    }
}

// MARK: -
// MARK: Foundation
extension DatabaseManager {
    // MARK: -
    // MARK: Deletes
    func delete(id: UUID,
                includedRemote: Bool = true,
                completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        let context = CoreDataManager.shared.mainContext
        guard let coredataDb = try? Database.fetchWithId(context, id) else {
            completion(.failure(DatabaseManagerError.localDatabaseNotFound))
            return
        }

        do {
            try Document.deleteWithPredicate(context, NSPredicate(format: "database_id = %@",
                                                                  id as CVarArg))
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion(.failure(error))
            return
        }
        coredataDb.delete(context)

        // Trigger updates for Advanced Settings
        NotificationCenter.default.post(name: .defaultDatabaseUpdate,
                                        object: DatabaseManager.defaultDatabase)

        guard includedRemote else {
            completion(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion(.success(false))
            return
        }

        if Configuration.beamObjectAPIEnabled {
            do {
                try self.deleteFromBeamObjectAPI(id, completion)
            } catch {
                completion(.failure(error))
            }
        } else {
            let databaseRequest = DatabaseRequest()

            do {
                // Remotely, deleting a database will delete all related documents
                try databaseRequest.delete(id.uuidString.lowercased()) { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .database)
                        completion(.failure(error))
                    case .success:
                        completion(.success(true))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .database)
                completion(.failure(error))
            }
        }
    }

    func deleteAll(includedRemote: Bool = true,
                   completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        do {
            try Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            completion?(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let databaseRequest = DatabaseRequest()

        do {
            try databaseRequest.deleteAll { result in
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
    func syncAll(completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        saveAllOnApi { result in
            if case .success(let success) = result, success == true {
                self.fetchAllOnApi(completion)
                return
            }

            completion?(result)
        }
    }

    /// Fetch most recent database from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ databaseStruct: DatabaseStruct,
                 _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        if Configuration.beamObjectAPIEnabled {
            try refreshFromBeamObjectAPIAndSaveLocally(databaseStruct, completion)
            return
        }

        fetchDatabaseFromAPI(databaseStruct.id, completion)
    }

    func refreshFromBeamObjectAPIAndSaveLocally(_ databaseStruct: DatabaseStruct,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        guard Configuration.beamObjectAPIEnabled else {
            throw BeamObjectManagerError.beamObjectAPIDisabled
        }

        try refreshFromBeamObjectAPI(databaseStruct, true) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let remoteDatabaseStruct):
                guard let remoteDatabaseStruct = remoteDatabaseStruct else {
                    Logger.shared.logDebug("\(databaseStruct.title): remote is not more recent",
                                           category: .documentNetwork)
                    completion?(.success(false))
                    return
                }

                guard remoteDatabaseStruct != databaseStruct else {
                    Logger.shared.logDebug("\(databaseStruct.title): remote is equal to stored version, skip",
                                           category: .documentNetwork)
                    completion?(.success(false))
                    return
                }

                // Saving the remote version locally
                self.coreDataManager.persistentContainer.performBackgroundTask { context in
                    let database = Database.rawFetchOrCreateWithId(context, databaseStruct.id)

                    do {
                        database.update(remoteDatabaseStruct)
                        completion?(.success(try Self.saveContext(context: context)))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    private func fetchDatabaseFromAPI(_ id: UUID,
                                      _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let databaseRequest = DatabaseRequest()

        do {
            try databaseRequest.fetchDatabase(id) { result in
                switch result {
                case .failure(let error):
                    if case APIRequestError.notFound = error {
                        try? self.deleteLocalDatabaseAndWait(id)
                    }
                    completion?(.failure(error))
                case .success(let databaseType):
                    self.fetchDatabaseFromAPISuccess(id, databaseType, completion)
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    private func deleteLocalDatabaseAndWait(_ id: UUID) throws {
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        try context.performAndWait {
            guard let database = try? Database.fetchWithId(context, id) else {
                return
            }

            database.deleted_at = BeamDate.now

            try Self.saveContext(context: context)
        }
    }

    private func fetchDatabaseFromAPISuccess(_ id: UUID,
                                             _ databaseType: DatabaseAPIType,
                                             _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // Saving the remote version locally
        coreDataManager.persistentContainer.performBackgroundTask { context in
            let database = Database.rawFetchOrCreateWithId(context, id)

            guard !self.isEqual(database, to: databaseType) else {
                Logger.shared.logDebug("\(database.title): remote is equal to stored version, skip",
                                       category: .documentNetwork)
                completion?(.success(false))
                return
            }

            do {
                self.updateDatabaseWithDatabaseAPIType(database, databaseType)

                completion?(.success(try Self.saveContext(context: context)))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // When saving multiple databases at once, one might raise issue (title)
    // If title is already used, we update it to another unique title
    private func saveAllOnApiErrors(_ errors: [UserErrorData]) throws -> Bool {
        var fixedAnyError = false

        for error in errors {
            if error.message == "Title has already been taken",
               error.path == ["attributes", "title"],
               let objectId = error.objectid,
               let uuid = UUID(uuidString: objectId) {

                fixedAnyError = try fixDuplicateTitle(uuid)
            }
        }

        return fixedAnyError
    }

    private func fixDuplicateTitle(_ databaseId: UUID) throws -> Bool {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        Logger.shared.logDebug("Changing database title", category: .database)
        if let database = try Database.fetchWithId(context, databaseId) {
            database.title = "\(database.title) \(databaseId)"
            try Self.saveContext(context: context)
            Logger.shared.logDebug("Changed database title", category: .databaseDebug)
            return true
        }

        return false
    }

    func saveAllOnApi(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil, _ nested: Int = 1) {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            do {
                let databases = try Database.rawFetchAll(context)
                let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }
                let databaseRequest = DatabaseRequest()

                try databaseRequest.saveAll(databasesArray) { result in
                    switch result {
                    case .failure(let error):
                        guard nested > 0 else {
                            completion?(.failure(error))
                            return
                        }

                        // Server returns errors when uploaded few databases at once, we try to correct
                        // errors and reupload if possible
                        do {
                            if case APIRequestError.apiErrors(let errorable) = error,
                               let errors = errorable.errors,
                               try self.saveAllOnApiErrors(errors) {
                                self.saveAllOnApi(completion, nested - 1)
                            } else if case APIRequestError.duplicateTitle = error,
                                      let firstDatabase = databasesArray.first,
                                      let databaseId = firstDatabase.id,
                                      let uuid = UUID(uuidString: databaseId),
                                      try self.fixDuplicateTitle(uuid) {
                                // Only happens if we uploaded 1 database
                                self.saveAllOnApi(completion, nested - 1)
                            } else {
                                // error: from request
                                completion?(.failure(error))
                            }
                        } catch {
                            // error: from catch
                            completion?(.failure(error))
                        }
                    case .success(let databasesApiType):
                        guard databasesApiType.databases?.count == databases.count else {
                            completion?(.success(false))
                            return
                        }
                        completion?(.success(true))
                    }
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func fetchAllOnApi(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        let databaseRequest = DatabaseRequest()

        // When fetching all databases, we only fetch updates since last call,
        // to prevent downloading all of them
        let lastUpdatedAt = Persistence.Sync.Databases.updated_at
        if let lastUpdatedAt = lastUpdatedAt {
            Logger.shared.logDebug("Using updatedAt for databases API call: \(lastUpdatedAt)", category: .databaseNetwork)
        }

        do {
            try databaseRequest.fetchAll(lastUpdatedAt) { result in
                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success(let databases):
                    self.coreDataManager.backgroundContext.performAndWait {
                        // exit early, no need to process further without any objects back
                        guard databases.count > 0 else {
                            Logger.shared.logDebug("0 database fetched.", category: .databaseNetwork)
                            completion?(.success(true))
                            return
                        }

                        let mostRecentUpdatedAt = databases.compactMap({ $0.updatedAt }).sorted().last

                        if let mostRecentUpdatedAt = mostRecentUpdatedAt {
                            Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(databases.count) databases fetched.",
                                                   category: .databaseNetwork)
                        }

                        for database in databases {
                            guard let database_id = database.id,
                                  let databaseId = UUID(uuidString: database_id) else { continue }
                            let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext,
                                                                             databaseId)
                            self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                        }

                        do {
                            try Self.saveContext(context: self.coreDataManager.backgroundContext)
                            // Will be used for the next `fetchAllOnApi` call
                            Persistence.Sync.Databases.updated_at = mostRecentUpdatedAt

                            completion?(.success(true))
                        } catch {
                            completion?(.failure(error))
                        }
                    }
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func save(_ databaseStruct: DatabaseStruct,
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
                    // We want to fetch back the database, to update it's previousChecksum
                    //  context.refresh(database, mergeChanges: false)
                    guard let updatedDatabase = try? Database.fetchWithId(context, databaseStruct.id) else {
                        Logger.shared.logError("Weird, database disappeared: \(databaseStruct.id) \(databaseStruct.title)", category: .coredata)
                        return
                    }

                    var updatedDatabaseStruct = DatabaseStruct(database: updatedDatabase)

                    if Configuration.beamObjectAPIEnabled {
                        do {
                            updatedDatabaseStruct.previousChecksum = updatedDatabaseStruct.beamObjectPreviousChecksum

                            try self.saveOnBeamObjectAPI(updatedDatabaseStruct) { result in
                                switch result {
                                case .failure(let error): networkCompletion?(.failure(error))
                                case .success: networkCompletion?(.success(true))
                                }
                            }
                        } catch {
                            networkCompletion?(.failure(error))
                        }
                    } else {
                        self.saveDatabaseStructOnAPI(updatedDatabaseStruct, networkCompletion)
                    }
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

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        do {
            let databaseApiType = databaseStruct.asApiType()
            try databaseRequest.save(databaseApiType) { result in
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
    func delete(_ database: DatabaseStruct, includedRemote: Bool = true) -> PromiseKit.Promise<Bool> {
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

                    let dbId = database.id.uuidString.lowercased()
                    let result: PromiseKit.Promise<DatabaseAPIType?> = databaseRequest.delete(dbId)
                    return result.map(on: self.backgroundQueue) { _ in true }
                }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> PromiseKit.Promise<Bool> {
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

        let promise: PromiseKit.Promise<Bool> = databaseRequest.deleteAll()

        return promise
    }

    // MARK: -
    // MARK: Bulk calls
    func syncAll() -> PromiseKit.Promise<Bool> {
        let promise: PromiseKit.Promise<Bool> = saveAllOnApi()

        return promise.then { result -> PromiseKit.Promise<Bool> in
            guard result == true else { return .value(result) }

            return self.fetchAllOnApi()
        }
    }

    func saveAllOnApi(_ nested: Int = 1) -> PromiseKit.Promise<Bool> {
        self.coreDataManager.background()
            .then(on: backgroundQueue) { context -> PromiseKit.Promise<Bool> in
                try context.performAndWait {
                    let databaseRequest = DatabaseRequest()

                    let databases = try Database.rawFetchAll(context)
                    let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }

                    let saveDBPromise: PromiseKit.Promise<[DatabaseAPIType]> = databaseRequest.saveAll(databasesArray)

                    return saveDBPromise.map { _ in true }
                }
            }.recover(on: backgroundQueue) { error throws -> PromiseKit.Promise<Bool> in
                guard case APIRequestError.apiErrors(let errorable) = error,
                      let errors = errorable.errors,
                   try self.saveAllOnApiErrors(errors),
                   nested > 0 else {
                    throw error
                }

                return self.saveAllOnApi(nested - 1)
            }
    }

    func fetchAllOnApi() -> PromiseKit.Promise<Bool> {
        let databaseRequest = DatabaseRequest()

        let promise: PromiseKit.Promise<[DatabaseAPIType]> =
            databaseRequest.fetchAll(Persistence.Sync.Databases.updated_at)

        return promise
            .then(on: backgroundQueue) { databases -> PromiseKit.Promise<Bool> in
                try self.coreDataManager.backgroundContext.performAndWait {
                    guard databases.count > 0 else {
                        Logger.shared.logDebug("0 database fetched.", category: .database)
                        return .value(true)
                    }

                    let mostRecentUpdatedAt = databases.compactMap({ $0.updatedAt }).sorted().last

                    if let mostRecentUpdatedAt = mostRecentUpdatedAt {
                        Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(databases.count) databases fetched.",
                                               category: .database)
                    }

                    for database in databases {
                        guard let database_id = database.id,
                              let databaseId = UUID(uuidString: database_id) else { continue }
                        let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext,
                                                                         databaseId)
                        self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                    }

                    try Self.saveContext(context: self.coreDataManager.backgroundContext)

                    Persistence.Sync.Databases.updated_at = mostRecentUpdatedAt

                    return .value(true)
                }
            }
    }

    func saveOnApi(_ databaseStruct: DatabaseStruct) -> PromiseKit.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return .value(false)
        }

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        let promise: PromiseKit.Promise<DatabaseAPIType> = databaseRequest.save(databaseStruct.asApiType())

        return promise.map(on: backgroundQueue) { _ in true }
    }

    func save(_ databaseStruct: DatabaseStruct) -> PromiseKit.Promise<Bool> {
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
                    return self.saveOnApi(updatedDatabaseStruct)
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
    func delete(_ database: DatabaseStruct, includedRemote: Bool = true) -> Promises.Promise<Bool> {
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
                    NotificationCenter.default.post(name: .defaultDatabaseUpdate,
                                                    object: DatabaseManager.defaultDatabase)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled,
                          includedRemote else {
                        return Promise(false)
                    }

                    let dbId = database.id.uuidString.lowercased()
                    let result: Promises.Promise<DatabaseAPIType?> = databaseRequest.delete(dbId)
                    return result.then(on: self.backgroundQueue) { _ in true }
                }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> Promises.Promise<Bool> {
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

        let promise: Promises.Promise<Bool> = databaseRequest.deleteAll()

        return promise
    }

    // MARK: -
    // MARK: Bulk calls
    func syncAll() -> Promises.Promise<Bool> {
        let promise: Promises.Promise<Bool> = saveAllOnApi()

        return promise.then { result -> Promises.Promise<Bool> in
            guard result == true else { return Promise(result) }

            return self.fetchAllOnApi()
        }
    }

    func saveAllOnApi(_ nested: Int = 1) -> Promises.Promise<Bool> {
        self.coreDataManager.background()
            .then(on: backgroundQueue) { context in
                try context.performAndWait {
                    let databaseRequest = DatabaseRequest()

                    let databases = try Database.rawFetchAll(context)
                    let databasesArray: [DatabaseAPIType] = databases.map { database in database.asApiType() }

                    let saveDBPromise: Promises.Promise<[DatabaseAPIType]> = databaseRequest.saveAll(databasesArray)

                    return saveDBPromise.then { _ in true }
                }
            }.recover(on: backgroundQueue) { error throws -> Promises.Promise<Bool> in
                // We might have fixable errors like title conflicts
                guard case APIRequestError.apiErrors(let errorable) = error,
                      let errors = errorable.errors,
                   try self.saveAllOnApiErrors(errors),
                   nested > 0 else {
                    throw error
                }

                return self.saveAllOnApi(nested - 1)
            }
    }

    func fetchAllOnApi() -> Promises.Promise<Bool> {
        let databaseRequest = DatabaseRequest()

        let promise: Promises.Promise<[DatabaseAPIType]> =
            databaseRequest.fetchAll(Persistence.Sync.Databases.updated_at)

        return promise
            .then(on: backgroundQueue) { databases -> Promises.Promise<Bool> in
                try self.coreDataManager.backgroundContext.performAndWait {
                    guard databases.count > 0 else {
                        Logger.shared.logDebug("0 database fetched.", category: .database)
                        return Promise(true)
                    }

                    let mostRecentUpdatedAt = databases.compactMap({ $0.updatedAt }).sorted().last

                    if let mostRecentUpdatedAt = mostRecentUpdatedAt {
                        Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(databases.count) databases fetched.",
                                               category: .database)
                    }

                    for database in databases {
                        guard let database_id = database.id,
                              let databaseId = UUID(uuidString: database_id) else { continue }
                        let localDatabase = Database.fetchOrCreateWithId(self.coreDataManager.backgroundContext,
                                                                         databaseId)
                        self.updateDatabaseWithDatabaseAPIType(localDatabase, database)
                    }

                    try Self.saveContext(context: self.coreDataManager.backgroundContext)

                    Persistence.Sync.Databases.updated_at = mostRecentUpdatedAt

                    return Promise(true)
                }
            }
    }

    func saveOnApi(_ databaseStruct: DatabaseStruct) -> Promises.Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(false)
        }

        Self.networkRequests[databaseStruct.id]?.cancel()
        let databaseRequest = DatabaseRequest()
        Self.networkRequests[databaseStruct.id] = databaseRequest

        let promise: Promises.Promise<DatabaseAPIType> = databaseRequest.save(databaseStruct.asApiType())

        return promise.then(on: backgroundQueue) { _ in true }
    }

    func save(_ databaseStruct: DatabaseStruct) -> Promises.Promise<Bool> {
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
                    return self.saveOnApi(updatedDatabaseStruct)
                }
            }.always {
                self.saveDatabasePromiseCancels[databaseStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDatabasePromiseCancels[databaseStruct.id] = cancel

        return result
    }
}

// MARK: - BeamObjectManagerDelegateProtocol
extension DatabaseManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    //swiftlint:disable:next function_body_length
    func receivedObjects(_ databases: [DatabaseStruct]) throws {
        Logger.shared.logDebug("Received \(databases.count) databases: updating",
                               category: .databaseNetwork)
        let context = coreDataManager.backgroundContext
        var changedDatabases: [DatabaseStruct] = []
        try context.performAndWait {
            var changed = false

            for var database in databases {
                let localDatabase = Database.fetchOrCreateWithId(context, database.id)

                if self.isEqual(localDatabase, to: database) {
                    Logger.shared.logDebug("\(database.title) {\(database.id)}: remote is equal to struct version, skip",
                                           category: .databaseNetwork)
                    continue
                }

                var good = false
                let originalTitle = database.title
                var index = 2

                while !good {
                    do {
                        localDatabase.update(database)
                        localDatabase.beam_object_previous_checksum = database.checksum

                        try checkValidations(context, localDatabase)

                        good = true
                    } catch {
                        database.title = "\(originalTitle) \(index)"
                        index += 1
                    }
                }

                // Database's title was changed, we need to save it on the API to propagate to other devices
                if index > 2 {
                    changedDatabases.append(database)
                }

                changed = true
            }

            if changed {
                try Self.saveContext(context: context)
            }
        }

        try saveOnBeamObjectsAPI(changedDatabases)

        Logger.shared.logDebug("Received \(databases.count) databases: updated",
                               category: .databaseNetwork)
    }

    func allObjects() throws -> [DatabaseStruct] {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        // Note: when this becomes a memory hog because we manipulate all local databases, we'll want to loop through
        // them by 100s and make multiple network calls instead.
        return try context.performAndWait {
            try Database.rawFetchAll(context).map {
                var result = DatabaseStruct(database: $0)
                result.previousChecksum = result.beamObjectPreviousChecksum
                return result
            }
        }
    }

    func persistChecksum(_ objects: [DatabaseStruct]) throws {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        try context.performAndWait {
            for updateObject in objects {
                guard let databaseCoreData = try? Database.fetchWithId(context, updateObject.id) else {
                    throw DatabaseManagerError.localDatabaseNotFound
                }

                databaseCoreData.beam_object_previous_checksum = updateObject.previousChecksum
            }

            try Self.saveContext(context: context)
        }
    }
}

// swiftlint:enable file_length
