import Foundation
import PromiseKit
import BeamCore

extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi() -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        self.willSaveAllOnBeamObjectApi()

        var objects: [BeamObjectType]
        do {
            objects = try allObjects(updatedSince: Persistence.Sync.BeamObjects.last_updated_at)
        } catch {
            return Promise(error: error)
        }

        let promise: Promise<[BeamObjectType]> = saveOnBeamObjectsAPI(objects)
        return promise
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        let promise: Promise<[BeamObjectType]> = objectManager.saveToAPI(objects)
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return promise.map(on: backgroundQueue) { remoteObjects in
            try self.persistChecksum(remoteObjects)
            return remoteObjects
        }.recover(on: backgroundQueue) { error -> Promise<[BeamObjectType]> in
            Logger.shared.logError("Could not save all \(objects.count) \(BeamObjectType.beamObjectTypeName) objects: \(error.localizedDescription)",
                                   category: .beamObjectNetwork)

            if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error {
                return self.manageInvalidChecksum(error)
            }

            // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
            guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
                throw error
            }

            return self.manageMultipleErrors(objects, errors)
        }
    }

    internal func manageInvalidChecksum(_ error: Error) -> Promise<[BeamObjectType]> {
        // Early return except for checksum issues.
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects,
                                                                                let goodObjects,
                                                                                let remoteObjects) = error else {
            return Promise(error: error)
        }

        do {
            var mergedObjects: [BeamObjectType] = []

            for conflictedObject in conflictedObjects {
                if let remoteObject = remoteObjects.first(where: { $0.beamObjectId == conflictedObject.beamObjectId }) {
                    var mergedObject = try manageConflict(conflictedObject, remoteObject)
                    mergedObject.previousChecksum = remoteObject.checksum

                    mergedObjects.append(mergedObject)
                } else {
                    // The remote object doesn't exist, we can just resend it without a `previousChecksum` to create it
                    // server-side
                    var mergedObject = try conflictedObject.copy()
                    mergedObject.previousChecksum = nil

                    mergedObjects.append(mergedObject)
                }
            }

            let promise: Promise<[BeamObjectType]> = self.saveOnBeamObjectsAPI(mergedObjects)
            let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

            return promise.map(on: backgroundQueue) { remoteObjects in
                var allObjects: [BeamObjectType] = []
                allObjects.append(contentsOf: goodObjects)
                allObjects.append(contentsOf: remoteObjects)

                try self.saveObjectsAfterConflict(remoteObjects)

                return allObjects
            }.recover(on: backgroundQueue) { error -> Promise<[BeamObjectType]> in
                if !goodObjects.isEmpty {
                    try? self.persistChecksum(goodObjects)
                }
                throw error
            }
        } catch {
            return Promise(error: error)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func manageMultipleErrors(_ objects: [BeamObjectType],
                                       _ errors: [Error]) -> Promise<[BeamObjectType]> {
        var newObjects: [BeamObjectType] = []
        var goodObjects: [BeamObjectType] = []
        for insideError in errors {
            /*
             We have multiple errors. If all errors are about invalid checksums, we can fix and retry. Else we'll just
             stop and call the completion handler with the original error
             */
            guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects,
                                                                                    let errorGoodObjects,
                                                                                    let remoteObjects) = insideError else {
                return Promise(error: BeamObjectManagerError.multipleErrors(errors))
            }

            guard let conflictedObject = conflictedObjects.first, conflictedObjects.count == 1 else {
                return Promise(error: BeamObjectManagerDelegateError.runtimeError("Had more than one object back"))
            }

            guard let remoteObject = remoteObjects.first, remoteObjects.count == 1 else {
                return Promise(error: BeamObjectManagerDelegateError.runtimeError("Had more than one object back"))
            }

            do {
                var mergedObject = try manageConflict(conflictedObject, remoteObject)
                mergedObject.previousChecksum = remoteObject.checksum

                goodObjects.append(contentsOf: errorGoodObjects)
                newObjects.append(mergedObject)
            } catch {
                return Promise(error: error)
            }
        }

        let promise: Promise<[BeamObjectType]> = saveOnBeamObjectsAPI(newObjects)
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return promise.map(on: backgroundQueue) { newObjectsSaved in
            try self.saveObjectsAfterConflict(newObjectsSaved)
            return goodObjects + newObjectsSaved
        }
    }

    func deleteFromBeamObjectAPI(_ id: UUID) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return objectManager.delete(id).map(on: backgroundQueue) { _ in true }
    }

    func deleteFromBeamObjectAPI(_ ids: [UUID]) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let promises: [Promise<Bool>] = ids.map {
            deleteFromBeamObjectAPI($0)
        }
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return firstly {
            when(fulfilled: promises).asVoid().then(on: backgroundQueue) {
                Promise.value(true)
            }
        }
    }

    func deleteAllFromBeamObjectAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        return objectManager.deleteAll(BeamObjectType.beamObjectTypeName)
    }

    func refreshFromBeamObjectAPI(_ object: BeamObjectType,
                                  _ forced: Bool = false) -> Promise<BeamObjectType?> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        guard !forced else {
            return objectManager.fetchObject(object).then(on: backgroundQueue) {
                Promise.value($0)
            }
        }

        return objectManager.fetchObjectUpdatedAt(object).then(on: backgroundQueue) { updatedAt -> Promise<BeamObjectType?> in
            guard let updatedAt = updatedAt, updatedAt > object.updatedAt else {
                return .value(nil)
            }

            return objectManager.fetchObject(object).then(on: backgroundQueue) {
                Promise.value($0)
            }
        }.recover(on: backgroundQueue) { error -> Promise<BeamObjectType?> in
            if case APIRequestError.notFound = error {
                return .value(nil)
            }
            throw error
        }
    }

    func fetchAllFromBeamObjectAPI() -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()

        return objectManager.fetchAllObjects()
    }

    func saveOnBeamObjectAPI(_ object: BeamObjectType) -> Promise<BeamObjectType> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        let promise: Promise<BeamObjectType> = objectManager.saveToAPI(object)

        return promise.then(on: backgroundQueue) { remoteObject -> Promise<BeamObjectType> in
            try self.persistChecksum([remoteObject])
            return .value(remoteObject)
        }.recover(on: backgroundQueue) { error -> Promise<BeamObjectType> in
            guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error else {
                throw error
            }

            let promise2: Promise<[BeamObjectType]> = self.manageInvalidChecksum(error)
            return promise2.map(on: backgroundQueue) { objects in
                guard let newObject = objects.first, objects.count == 1 else {
                    throw BeamObjectManagerDelegateError.runtimeError("Had more than one object back")
                }

                try self.persistChecksum([newObject])
                return newObject
            }
        }
    }
}
