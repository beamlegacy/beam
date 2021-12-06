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
                do {
                    try checkValidations(context, localDatabase)
                } catch {
                    Logger.shared.logError("saveObjectsAfterConflict checkValidations: \(error.localizedDescription)",
                                           category: .database)
                    localDatabase.deleted_at = BeamDate.now
                }
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
        let context = coreDataManager.backgroundContext
        var changedDatabases: [DatabaseStruct] = []

        try context.performAndWait {
            var changed = false

            for var database in databases {
                let localDatabase = Database.fetchOrCreateWithId(context, database.id)

                if self.isEqual(localDatabase, to: database) {
                    continue
                }

                var good = false

                var (originalTitle, index) = database.title.originalTitleWithIndex()

                while !good && index < 10 {
                    do {
                        localDatabase.update(database)

                        try checkValidations(context, localDatabase)

                        good = true
                    } catch {
                        // I don't need to flag this object `deleted` like I do for DocumentStruct because
                        // Database `checkValidations` only has title checks. In such case, changing the title.
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

        if !changedDatabases.isEmpty {
            Logger.shared.logDebug("Received \(databases.count) databases: \(changedDatabases.count) remodified",
                                   category: .databaseNetwork)
        }
    }

    func allObjects(updatedSince: Date?) throws -> [DatabaseStruct] {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        // Note: when this becomes a memory hog because we manipulate all local databases, we'll want to loop through
        // them by 100s and make multiple network calls instead.
        return try context.performAndWait {
            var predicate: NSPredicate?
            if let updatedSince = updatedSince {
                predicate = NSPredicate(format: "updated_at >= %@", updatedSince as CVarArg)
            }

            return try Database.rawFetchAll(context, predicate).map {
                DatabaseStruct(database: $0)
            }
        }
    }
}
