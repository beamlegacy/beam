import Foundation
import BeamCore
import PromiseKit

extension DatabaseManager {
    func syncAll() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return .value(false)
        }

        let promise: Promise<Bool> = saveAllOnApi()

        return promise.then { result -> Promise<Bool> in
            guard result == true else { return .value(result) }

            return self.fetchAllOnApi()
        }
    }

    func saveAllOnApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return .value(false)
        }

        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()

        return promise.then(on: backgroundQueue) { context -> Promise<Bool> in
            let databases = try Database.rawFetchAll(context)
            Logger.shared.logDebug("Uploading \(databases.count) databases", category: .databaseNetwork)
            if databases.isEmpty {
                return .value(true)
            }

            let databaseStructs = databases.map { DatabaseStruct(database: $0) }
            let savePromise: Promise<[DatabaseStruct]> = self.saveOnBeamObjectsAPI(databaseStructs)

            return savePromise.then(on: self.backgroundQueue) { savedDatabaseStructs -> Promise<Bool> in
                guard savedDatabaseStructs.count == databases.count else {
                    return .value(false)
                }
                return .value(true)
            }
        }
    }

    func fetchAllOnApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            return .value(false)
        }

        let promise: Promise<[DatabaseStruct]> = self.fetchAllFromBeamObjectAPI()

        return promise.then(on: backgroundQueue) { databases -> Promise<Bool> in
            try self.receivedObjects(databases)
            return .value(true)
        }
    }

    // MARK: -
    // MARK: Deletes
    func delete(_ database: DatabaseStruct, includedRemote: Bool = true) -> Promise<Bool> {
        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()

        return promise
            .then(on: backgroundQueue) { context -> Promise<Bool> in
                try context.performAndWait {
                    guard let coreDataDatabase = try? Database.fetchWithId(context, database.id) else {
                        throw DatabaseManagerError.localDatabaseNotFound
                    }

                    try DocumentManager().deleteAll(databaseId: database.id)
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

                    return self.deleteFromBeamObjectAPI(database.beamObjectId)
                }
            }
    }

    func deleteAll(includedRemote: Bool = true) -> Promise<Bool> {
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

        return self.deleteAllFromBeamObjectAPI()
    }

    func save(_ databaseStruct: DatabaseStruct) -> Promise<Bool> {
        let promise: Guarantee<NSManagedObjectContext> = coreDataManager.background()
        var cancelme = false

        // Cancel previous promise
        saveDatabasePromiseCancels[databaseStruct.id]?()

        let result = promise
            .then(on: self.backgroundQueue) { context -> Promise<Bool> in
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

                    return self.saveOnBeamObjectAPI(updatedDatabaseStruct).map(on: self.backgroundQueue) { _ in true }
                }
            }.ensure {
                self.saveDatabasePromiseCancels[databaseStruct.id] = nil
            }

        let cancel = { cancelme = true }

        saveDatabasePromiseCancels[databaseStruct.id] = cancel

        return result
    }
}
