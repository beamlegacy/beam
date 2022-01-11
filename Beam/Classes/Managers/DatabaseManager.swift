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
    var coreDataManager: CoreDataManager
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    let saveDatabaseQueue = OperationQueue()

    internal static var backgroundQueue = DispatchQueue(label: "DatabaseManager backgroundQueue", qos: .default)
    var saveDatabasePromiseCancels: [UUID: () -> Void] = [:]

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
            UserAlert.showError(message: "Database changed",
                                informativeText: "DB Changed from \(oldValue.title) {\(oldValue.id)} to \(newValue.title) {\(newValue.id)}. Beam must exit now.",
                                buttonTitle: "Exit now")

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
                Logger.shared.logError("Conflicting \(database.titleAndId), database: \(database)",
                                       category: .coredata)
            }

            if let database = conflict.databaseObject as? Database {
                Logger.shared.logError("Existing database \(database.titleAndId), database: \(database)",
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

    func checkValidations(_ context: NSManagedObjectContext, _ database: Database) throws {
        guard database.deleted_at == nil else { return }

        try checkDuplicateTitles(context, database)
    }

    private func checkDuplicateTitles(_ context: NSManagedObjectContext, _ database: Database) throws {
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
        DocumentManager().count(filters: [.databaseId(id)])
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

    func isEqual(_ database: Database, to databaseStruct: DatabaseStruct) -> Bool {
        // Server side doesn't store milliseconds for updatedAt and createdAt.
        // Local coredata does, rounding using Int() to compare them

        database.updated_at.intValue == databaseStruct.updatedAt.intValue &&
            database.created_at.intValue == databaseStruct.createdAt.intValue &&
            database.title == databaseStruct.title &&
            database.deleted_at?.intValue == databaseStruct.deletedAt?.intValue &&
            database.id == databaseStruct.id
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
        DatabaseManager.defaultDatabase.title.prefix(7) == "Default"
    }

    /// Is database completly empty, without any documents
    static func isDatabaseEmpty(_ context: NSManagedObjectContext, _ databaseId: UUID) -> Bool {
        context.performAndWait {
            do {
                let documentManager = DocumentManager()
                for document in try documentManager.fetchAll(filters: [.databaseId(databaseId)]) {
                    guard DocumentStruct(document: document).isEmpty else {
                        Logger.shared.logDebug("document \(document.titleAndId) is not empty", category: .databaseDebug)
                        return false
                    }
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

            Logger.shared.logDebug("Databases found other than default: \(databases)", category: .database)
            let group = DispatchGroup()
            var errors: [Error] = []

            for database in databases {
                Logger.shared.logDebug("Looking at \(database.titleAndId)", category: .databaseDebug)

                // Only automatically created DB should be deleted.
                // TODO: we should add a `automaticCreated` in `Database` instead of checking for title
                if onlyAutomaticCreated, database.title.prefix(7) != "Default" {
                    Logger.shared.logDebug("Not automatic DB, skip", category: .databaseDebug)
                    continue
                }

                guard Self.isDatabaseEmpty(context, database.id) else {
                    Logger.shared.logDebug("Not empty DB, skip", category: .databaseDebug)
                    continue
                }

                Logger.shared.logDebug("Deleting", category: .databaseDebug)

                group.enter()
                self.delete(DatabaseStruct(database: database)) { result in
                    do { _ = try result.get() } catch { errors.append(error) }
                    group.leave()
                }
            }

            group.wait()

            guard errors.isEmpty else {
                let error = DatabaseManagerError.multipleErrors(errors)
                Logger.shared.logDebug(error.localizedDescription, category: .databaseDebug)
                completion(.failure(error))
                return
            }

            completion(.success(true))
        }
    }

    /// Special case when the defaultDatabase is empty, was probably recently created during Beam app start,
    /// and should be deleted first to not conflict with one we're receiving now from the API sync with the same title
    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity
    func deleteCurrentDatabaseIfEmpty() throws -> Bool {
        // Don't delete if the database was manually set
        guard Persistence.Database.currentDatabaseId == nil else { return false }

        guard Self.isDefaultDatabaseAutomaticallyCreated() else { return false }

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        var deleted = false

        try context.performAndWait {
            guard let databases = try? Database.fetchAll(context) else { return }
            guard databases.count > 1 else { return }

            // TODO: should memoize `Self.defaultDatabase.id` or have a version without CD call
            let defaultDatabase = Self.defaultDatabase
            let defaultDatabaseId = defaultDatabase.id

            let databasesWithoutDefault = databases.map { $0.id }.filter { $0 != defaultDatabaseId }
            guard !databasesWithoutDefault.isEmpty else { return }

            guard Self.isDatabaseEmpty(context, defaultDatabaseId) else {
                Logger.shared.logWarning("Default Database: \(Self.defaultDatabase.titleAndId) is NOT empty, not deleting",
                                         category: .databaseDebug)
                return
            }

            guard defaultDatabase.title.prefix(7) == "Default" else { return }

            deleted = true
            Logger.shared.logWarning("Default Database: \(Self.defaultDatabase.titleAndId) is empty, deleting now",
                                     category: .database)

            let semaphore = DispatchSemaphore(value: 0)
            var error: Error?

            delete(defaultDatabase) { result in
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

        return deleted
    }
}
