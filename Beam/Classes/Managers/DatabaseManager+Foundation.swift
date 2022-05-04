import Foundation
import BeamCore

extension DatabaseManager {
    func saveAllOnApi(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            do {
                let databases = try Database.rawFetchAll(context)
                Logger.shared.logDebug("Uploading \(databases.count) databases", category: .databaseNetwork)
                if databases.isEmpty {
                    completion?(.success(true))
                    return
                }

                let databaseStructs = databases.map { DatabaseStruct(database: $0) }
                Task {
                    do {
                        let savedDatabases = try await self.saveOnBeamObjectsAPI(databaseStructs)
                        guard savedDatabases.count == databases.count else {
                            completion?(.success(false))
                            return
                        }
                        completion?(.success(true))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func fetchAllOnApi(_ completion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        Task {
            do {
                let databases = try await self.fetchAllFromBeamObjectAPI()
                try self.receivedObjects(databases)
                completion?(.success(true))
            } catch {
                completion?(.failure(error))
            }
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

        Task {
            do {
                try await self.deleteAllFromBeamObjectAPI()
                completion?(.success(true))
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .database)
                completion?(.failure(error))
            }
        }
    }

    func softDelete(_ databaseStruct: DatabaseStruct,
                    includedRemote: Bool = true,
                    completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        Logger.shared.logDebug("Soft Deleting database \(databaseStruct.titleAndId)", category: .database)

        var databaseStruct = databaseStruct.copy()
        databaseStruct.deletedAt = databaseStruct.deletedAt ?? BeamDate.now
        do {
            let documentManager = DocumentManager()
            _ = try documentManager.softDeleteAll(databaseId: databaseStruct.id)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
        }

        databaseStruct.deletedAt = databaseStruct.deletedAt ?? BeamDate.now
        save(databaseStruct, includedRemote, nil, completion: completion)
    }

    func delete(_ databaseStruct: DatabaseStruct,
                includedRemote: Bool = true,
                completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        Logger.shared.logDebug("Deleting database \(databaseStruct.titleAndId)", category: .database)
        let id = databaseStruct.id

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        context.perform {
            guard let coredataDb = try? Database.fetchWithId(context, id) else {
                completion(.failure(DatabaseManagerError.localDatabaseNotFound))
                return
            }

            do {
                let documentManager = DocumentManager()
                let documents = try documentManager.fetchAll(filters: [.databaseId(id)]).map { DocumentStruct(document: $0)}

                _ = try documentManager.deleteAll(databaseId: id)
                coredataDb.delete(context)

                try Self.saveContext(context: context)

                // Trigger updates for Advanced Settings, will force update for the Picker listing all DBs
                // Important: Don't use `DatabaseManager.defaultDatabase` here as object, as it recreates a default DB.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .databaseListUpdate,
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

                Task {
                    do {
                        try await self.deleteWithBeamObjectAPI(database: databaseStruct, documents: documents)
                        completion(.success(true))
                    } catch {
                        completion(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .database)
                completion(.failure(error))
                return
            }
        }
    }

    private func deleteWithBeamObjectAPI(database: DatabaseStruct,
                                         documents: [DocumentStruct]) async throws {

        var errors: [Error] = []

        await withTaskGroup(of: Error?.self, body: { group in
            group.addTask {
                do {
                    try await self.deleteFromBeamObjectAPI(object: database)
                    return nil
                } catch {
                    return error
                }
            }
            group.addTask {
                do {
                    try await DocumentManager().deleteFromBeamObjectAPI(objects: documents)
                    return nil
                } catch {
                    return error
                }
            }
            for await error in group {
                if let error = error {
                    errors += [error]
                }
            }
        })
        guard errors.isEmpty else {
            throw DatabaseManagerError.multipleErrors(errors)
        }
    }

    /// Fetch most recent database from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ databaseStruct: DatabaseStruct,
                 _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        try refreshFromBeamObjectAPIAndSaveLocally(databaseStruct, completion)
    }

    func refreshFromBeamObjectAPIAndSaveLocally(_ databaseStruct: DatabaseStruct,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        Task {
            let remoteDatabaseStruct = try await refreshFromBeamObjectAPI(databaseStruct, true)
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
                    database.update(remoteDatabaseStruct)
                    let success = try Self.saveContext(context: context)
                    completion?(.success(success))
                } catch {
                    Logger.shared.logError("Error saving: \(error.localizedDescription)", category: .database)
                    completion?(.failure(error))
                }
            }
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func save(_ databaseStruct: DatabaseStruct,
              _ networkSave: Bool = true,
              _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil,
              completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(databaseStruct.titleAndId)", category: .database)
        let blockOperation = BlockOperation()
        blockOperation.addExecutionBlock { [weak blockOperation, weak self] in
            guard let self = self,
                  let blockOperation = blockOperation
            else { return }

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

                    let updatedDatabaseStruct = DatabaseStruct(database: updatedDatabase)
                    Task {
                        do {
                            _ = try await self.saveOnBeamObjectAPI(updatedDatabaseStruct)
                            networkCompletion?(.success(true))
                        } catch {
                            networkCompletion?(.failure(error))
                        }
                    }
                } else {
                    networkCompletion?(.failure(APIRequestError.notAuthenticated))
                }
            }

        }
        saveDatabaseQueue.addOperation(blockOperation)
    }
}
