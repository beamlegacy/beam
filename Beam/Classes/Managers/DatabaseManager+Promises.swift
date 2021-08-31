import Foundation
import BeamCore
import Promises

extension DatabaseManager {
    // MARK: -
    // MARK: Deletes
    func delete(_ database: DatabaseStruct, includedRemote: Bool = true) -> Promise<Bool> {
        let promise: Promise<NSManagedObjectContext> = coreDataManager.background()

        return promise
            .then(on: backgroundQueue) { context -> Promise<Bool> in
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
            .then(on: self.backgroundQueue) { context -> Promise<Bool> in
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
                    return self.saveOnBeamObjectAPI(updatedDatabaseStruct).then(on: self.backgroundQueue) { _ in
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
