import Foundation
import BeamCore
import Promises

extension DatabaseManager {
    func syncAll() -> Promise<Bool> {
        let promise: Promise<Bool> = saveAllOnApi()

        return promise.then { result -> Promise<Bool> in
            guard result == true else { return Promise(result) }

            return self.fetchAllOnApi()
        }
    }

    func saveAllOnApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return Promise(false)
        }

        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: Self.backgroundQueue) { context -> Promise<Bool> in
            let databases = try Database.rawFetchAll(context)
            Logger.shared.logDebug("Uploading \(databases.count) databases", category: .databaseNetwork)
            if databases.isEmpty {
                return Promise(true)
            }

            let databaseStructs = databases.map { DatabaseStruct(database: $0) }
            let savePromise: Promise<[DatabaseStruct]> = self.saveOnBeamObjectsAPI(databaseStructs)

            return savePromise.then(on: Self.backgroundQueue) { savedDatabaseStructs -> Promise<Bool> in
                guard savedDatabaseStructs.count == databases.count else {
                    return Promise(false)
                }
                return Promise(true)
            }
        }
    }

    func fetchAllOnApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return Promise(false)
        }

        let promise: Promise<[DatabaseStruct]> = self.fetchAllFromBeamObjectAPI()

        return promise.then(on: Self.backgroundQueue) { databases -> Promise<Bool> in
            try self.receivedObjects(databases)
            return Promise(true)
        }
    }

    // MARK: -
    // MARK: Deletes
    func delete(_ database: DatabaseStruct, includedRemote: Bool = true) -> Promise<Bool> {
        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()

        return promise
            .then(on: Self.backgroundQueue) { context -> Promise<Bool> in
                try context.performAndWait {
                    let documentManager = DocumentManager()
                    guard let coreDataDatabase = try? Database.fetchWithId(context, database.id) else {
                        throw DatabaseManagerError.localDatabaseNotFound
                    }

                    _ = try documentManager.deleteAll(databaseId: database.id)
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

                    return self.deleteFromBeamObjectAPI(database.beamObjectId)
                }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> Promise<Bool> {
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

        let request = BeamObjectRequest()

        let promise: Promise<Bool> = request.deleteAll(beamObjectType: Self.BeamObjectType.beamObjectTypeName)

        return promise
    }

    func save(_ databaseStruct: DatabaseStruct) -> Promise<Bool> {
        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false

        // Cancel previous promise
        saveDatabasePromiseCancels[databaseStruct.id]?()

        let result = promise
            .then(on: Self.backgroundQueue) { context -> Promise<Bool> in
                Logger.shared.logDebug("Saving database \(databaseStruct.title)", category: .database)

                guard !cancelme else { throw DatabaseManagerError.operationCancelled }

                return try context.performAndWait {
                    let database = Database.fetchOrCreateWithId(context, databaseStruct.id)
                    database.update(databaseStruct)
                    database.updated_at = BeamDate.now

                    guard !cancelme else { throw DatabaseManagerError.operationCancelled }
                    try Self.saveContext(context: context)

                    guard AuthenticationManager.shared.isAuthenticated,
                          Configuration.networkEnabled else {
                        return Promise(true)
                    }

                    context.refresh(database, mergeChanges: false)

                    let updatedDatabaseStruct = DatabaseStruct(database: database)
                    return self.saveOnBeamObjectAPI(updatedDatabaseStruct).then(on: Self.backgroundQueue) { _ in
                        true
                    }
                }
            }.always {
                self.saveDatabasePromiseCancels[databaseStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDatabasePromiseCancels[databaseStruct.id] = cancel

        return result
    }
}
