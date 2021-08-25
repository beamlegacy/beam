import Foundation
import PromiseKit
import Promises
import BeamCore

// swiftlint:disable file_length

enum DatabaseManagerError: Error {
    case operationCancelled
    case localDatabaseNotFound
    case titleAlreadyExists
    case multipleErrors([Error])
    case networkTimeout
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
        case .multipleErrors(let errors):
            return "Multiple errors: \(errors)"
        case .networkTimeout:
            return "Network timeout"
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
    private let backgroundQueue = DispatchQueue(label: "DatabaseManager backgroundQueue", qos: .background)
    private var saveDatabasePromiseCancels: [UUID: () -> Void] = [:]

    static var defaultDatabase: DatabaseStruct {
        get {
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
            return context.performAndWait {
                // We look at a default database set by the user
                if let currentDatabaseId = Persistence.Database.currentDatabaseId,
                   let database = try? Database.fetchWithId(context, currentDatabaseId) {
                    return DatabaseStruct(database: database)
                }

                // Reset it, it wasn't found with `fetchWithId` and is probably deleted since
                Persistence.Database.currentDatabaseId = nil

                // Saved Database not found, or none has been set, going for any existing one, most recent first
                let existingDB = try? Database.fetchFirst(context,
                                                          nil,
                                                          [NSSortDescriptor(key: "updated_at", ascending: false)])

                if existingDB == nil {
                    Logger.shared.logWarning("Create default database and reset BeamObjects sync last updated",
                                             category: .database)
                    Persistence.Sync.BeamObjects.last_received_at = nil
                }

                let database = existingDB ?? Database.fetchOrCreateWithTitle(context, "Default")

                if database.objectID.isTemporaryID {
                    do {
                        try saveContext(context: context)
                    } catch {
                        assert(false)
                        Logger.shared.logError(error.localizedDescription, category: .coredata)
                    }
                }

                return DatabaseStruct(database: database)
            }
        }
        set {
            guard newValue != defaultDatabase else { return }
            let oldValue = defaultDatabase
            Persistence.Database.currentDatabaseId = newValue.id
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

            Self.showRestartAlert(oldValue, newValue)
        }
    }

    static func showRestartAlert(_ oldValue: DatabaseStruct, _ newValue: DatabaseStruct) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .defaultDatabaseUpdate, object: newValue)

            // TODO: remove this once the app knows how to switch database live
            let alert = NSAlert()
            alert.messageText = "Database changed"
            alert.alertStyle = .critical
            alert.informativeText = "DB Changed from \(oldValue.title) {\(oldValue.id)} to \(newValue.title) {\(newValue.id)}. Beam must exit now."

            alert.addButton(withTitle: "Exit now")
            alert.runModal()

            NSApplication.shared.terminate(nil)
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
            let localTimer = BeamDate.now
            try CoreDataManager.save(context)
            Logger.shared.logDebug("[\(savedCount)] CoreDataManager saved", category: .coredata, localTimer: localTimer)
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
        database.updated_at = BeamDate.now
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

    // MARK: - Default database check

    /// Will check if the newDatabase we received is older than our current default database, and if our current default database has no document it will switch
    static func changeDefaultDatabaseIfNeeded() {
        // A default database was manually set by the user
        // guard Configuration.databaseId == nil else { return }

        guard isDefaultDatabaseAutomaticallyCreated() else { return }

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        context.perform {
            guard Database.countWithPredicate(context) > 1 else { return }
            guard isDefaultDatabaseEmpty(context) else { return }

            let predicate = NSPredicate(format: "id != %@", DatabaseManager.defaultDatabase.id as CVarArg)
            let sortDescriptor = NSSortDescriptor(key: "updated_at", ascending: false)
            guard let databases = try? Database.fetchAll(context, predicate, [sortDescriptor]) else { return }
            for database in databases {
                guard !isDatabaseEmpty(context, database.id) else { continue }

                Logger.shared.logInfo("Changing default database to \(database.title) {\(database.id)}",
                                      category: .database)

                DatabaseManager.defaultDatabase = DatabaseStruct(database: database)

                return
            }
        }
    }

    private static func isDefaultDatabaseEmpty(_ context: NSManagedObjectContext) -> Bool {
        isDatabaseEmpty(context, Self.defaultDatabase.id)
    }

    // TODO: we should add a `automaticCreated` in `Database` to know when we created one automatically at start, so a
    // user creating one manually with `Default` as title won't match this
    private static func isDefaultDatabaseAutomaticallyCreated() -> Bool {
        DatabaseManager.defaultDatabase.title == "Default"
    }

    /// Is database completly empty, without any documents
    private static func isDatabaseEmpty(_ context: NSManagedObjectContext, _ databaseId: UUID) -> Bool {
        context.performAndWait {
            do {
                for document in try Document.fetchAll(context, nil, nil, databaseId) {
                    guard DocumentStruct(document: document).isEmpty else { return false }
                }
            } catch { return false }

            return true
        }
    }

    /// Delete all empty databases, including their empty documents. Delete on the API.
    func deleteEmptyDatabases(onlyAutomaticCreated: Bool = true,
                              completion: (Swift.Result<Bool, Error>) -> Void) {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        context.performAndWait {
            let predicate = NSPredicate(format: "id != %@", DatabaseManager.defaultDatabase.id as CVarArg)
            guard let databases = try? Database.fetchAll(context, predicate) else { return }

            let group = DispatchGroup()
            var errors: [Error] = []

            for database in databases {
                // Only automatically created DB should be deleted.
                // TODO: we should add a `automaticCreated` in `Database` instead of checking for title
                if onlyAutomaticCreated, database.title.prefix(7) != "Default" { continue }

                guard Self.isDatabaseEmpty(context, database.id) else { continue }

                group.enter()
                self.delete(id: database.id) { result in
                    do { _ = try result.get() } catch { errors.append(error) }
                    group.leave()
                }
            }

            group.wait()

            guard errors.isEmpty else {
                completion(.failure(DatabaseManagerError.multipleErrors(errors)))
                return
            }

            completion(.success(true))
        }
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
            let documentIds = try Document.fetchAll(context, NSPredicate(format: "database_id = %@", id as CVarArg)).map { $0.id }

            try Document.deleteWithPredicate(context, NSPredicate(format: "database_id = %@", id as CVarArg))
            coredataDb.delete(context)

            try Self.saveContext(context: context)

            // Trigger updates for Advanced Settings, will force update for the Picker listing all DBs
            // Important: Don't use `DatabaseManager.defaultDatabase` here as object, as it recreates a default DB.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .defaultDatabaseUpdate,
                                                object: nil)
            }

            guard includedRemote else {
                completion(.success(true))
                return
            }

            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
                completion(.success(false))
                return
            }

            if Configuration.beamObjectAPIEnabled {
                deleteWithBeamObjectAPI(id, documentIds, completion)
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
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion(.failure(error))
            return
        }
    }

    private func deleteWithBeamObjectAPI(_ id: UUID,
                                         _ documentIds: [UUID],
                                         _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        guard Configuration.beamObjectAPIEnabled else { return }

        do {

            let group = DispatchGroup()
            var errors: [Error] = []
            let lock = DispatchSemaphore(value: 1)

            // Delete database
            group.enter()
            try self.deleteFromBeamObjectAPI(id) { result in
                switch result {
                case .success: break
                case .failure(let error):
                    lock.wait()
                    errors.append(error)
                    lock.signal()
                }
                group.leave()
            }

            let documentManager = DocumentManager()

            group.enter()
            try documentManager.deleteFromBeamObjectAPI(documentIds) { result in
                switch result {
                case .success: break
                case .failure(let error):
                    lock.wait()
                    errors.append(error)
                    lock.signal()
                }
                group.leave()
            }

            group.wait()

            guard errors.isEmpty else {
                completion(.failure(DatabaseManagerError.multipleErrors(errors)))
                return
            }

            completion(.success(true))
        } catch {
            completion(.failure(error))
        }
    }

    func deleteAll(includedRemote: Bool = true,
                   completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        do {
            try Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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
                    Logger.shared.logError("\(databaseStruct.title): Couldn't fetch the remote database",
                                           category: .documentNetwork)
                    completion?(.success(false))
                    return
                }

                // Saving the remote version locally
                self.coreDataManager.persistentContainer.performBackgroundTask { context in
                    let database = Database.rawFetchOrCreateWithId(context, databaseStruct.id)

                    do {
                        database.beam_object_previous_checksum = remoteDatabaseStruct.checksum
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
                                       category: .databaseNetwork)
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
        Logger.shared.logDebug("Saving \(databaseStruct.titleAndId)", category: .database)
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

                database.updated_at = BeamDate.now

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
                    try Self.saveContext(context: context)

                    // Trigger updates for Advanced Settings
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .defaultDatabaseUpdate,
                                                        object: nil)
                    }

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
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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
                    database.updated_at = BeamDate.now

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
                    try Self.saveContext(context: context)

                    // Trigger updates for Advanced Settings
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .defaultDatabaseUpdate,
                                                        object: nil)
                    }
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
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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
                    database.updated_at = BeamDate.now

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

    func willSaveAllOnBeamObjectApi() {}

    //swiftlint:disable:next function_body_length
    func receivedObjects(_ databases: [DatabaseStruct]) throws {
        Logger.shared.logDebug("Received \(databases.count) databases",
                               category: .databaseNetwork)
        let context = coreDataManager.backgroundContext
        let localTimer = BeamDate.now
        var changedDatabases: [DatabaseStruct] = []

        try deleteCurrentDatabaseIfEmpty(databases, context)

        try context.performAndWait {
            var changed = false

            for var database in databases {
                let localDatabase = Database.fetchOrCreateWithId(context, database.id)

                if self.isEqual(localDatabase, to: database) {
                    Logger.shared.logDebug("\(database.titleAndId): remote is equal to struct version, skip",
                                           category: .databaseNetwork)
                    continue
                }

                var good = false

                var (originalTitle, index) = database.title.originalTitleWithIndex()

                while !good && index < 10 {
                    do {
                        localDatabase.update(database)
                        localDatabase.beam_object_previous_checksum = database.checksum

                        try checkValidations(context, localDatabase)

                        good = true
                    } catch {
                        database.title = "\(originalTitle) (\(index))"
                        Logger.shared.logWarning("Validation issue, new title is \(database.title)",
                                                 category: .databaseNetwork)
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

        if !changedDatabases.isEmpty {
            try saveOnBeamObjectsAPI(changedDatabases)
        }

        Logger.shared.logDebug("Received \(databases.count) databases: done. \(changedDatabases.count) remodified",
                               category: .databaseNetwork,
                               localTimer: localTimer)
    }

    /// Special case when the defaultDatabase is empty, was probably recently created during Beam app start,
    /// and should be deleted first to not conflict with one we're receiving now from the API sync with the same title
    private func deleteCurrentDatabaseIfEmpty(_ databases: [DatabaseStruct], _ context: NSManagedObjectContext) throws {
        // Don't delete if the database was manually set
        guard Persistence.Database.currentDatabaseId == nil else { return }

        // TODO: should memoize `Self.defaultDatabase.id` or have a version without CD call
        let defaultDatabaseId = Self.defaultDatabase.id

        let databasesWithoutDefault = databases.map { $0.id }.filter { $0 != defaultDatabaseId }
        guard !databasesWithoutDefault.isEmpty else { return }

        guard Self.isDatabaseEmpty(context, defaultDatabaseId) else { return }

        Logger.shared.logWarning("Default Database: \(Self.defaultDatabase.titleAndId) is empty, deleting now",
                                 category: .database)

        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?

        delete(id: defaultDatabaseId) { result in
            switch result {
            case .failure(let deleteError): error = deleteError
            case .success: break
            }
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(30))
        if case .timedOut = semaphoreResult {
            throw DatabaseManagerError.networkTimeout
        }

        if let error = error { throw error }
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
