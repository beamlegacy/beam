import Foundation
import BeamCore

extension DatabaseManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func saveObjectsAfterConflict(_ objects: [DatabaseStruct]) throws {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        try context.performAndWait {
            for updateObject in objects {
                guard let localDatabase = try Database.fetchWithId(context, updateObject.id) else {
                    throw DatabaseManagerError.localDatabaseNotFound
                }

                localDatabase.update(updateObject)
                localDatabase.beam_object_previous_checksum = updateObject.checksum
                try checkValidations(context, localDatabase)
            }
            try Self.saveContext(context: context)
        }
    }

    func manageConflict(_ dbStruct: DatabaseStruct,
                        _ remoteDbStruct: DatabaseStruct) throws -> DatabaseStruct {
        fatalError("Managed by BeamObjectManager")
    }

    //swiftlint:disable:next function_body_length
    func receivedObjects(_ databases: [DatabaseStruct]) throws {
        Logger.shared.logDebug("Received \(databases.count) databases",
                               category: .databaseNetwork)
        let context = coreDataManager.backgroundContext
        let localTimer = BeamDate.now
        var changedDatabases: [DatabaseStruct] = []

        if Configuration.shouldDeleteEmptyDatabase {
            try deleteCurrentDatabaseIfEmpty(databases, context)
        }

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
            let semaphore = DispatchSemaphore(value: 0)
            try saveOnBeamObjectsAPI(Array(changedDatabases)) { _ in
                semaphore.signal()

            }

            let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
            if case .timedOut = semaphoreResult {
                Logger.shared.logError("Semaphore timedout", category: .documentNetwork)
            }
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
        let defaultDatabase = Self.defaultDatabase
        let defaultDatabaseId = defaultDatabase.id

        let databasesWithoutDefault = databases.map { $0.id }.filter { $0 != defaultDatabaseId }
        guard !databasesWithoutDefault.isEmpty else { return }

        guard Self.isDatabaseEmpty(context, defaultDatabaseId) else { return }

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
