import Foundation
import Promises

/*
 Those are not yet ready to be used
 */
extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        self.willSaveAllOnBeamObjectApi()
        var objects: [BeamObjectType]
        do {
            objects = try allObjects()
        } catch {
            return Promise(error)
        }

        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
        return saveOnBeamObjectsAPI(objects).then(on: backgroundQueue) { _ in
            true
        }
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectsToSave = updatedObjectsOnly(objects)

        guard !objectsToSave.isEmpty else {
            return Promise([])
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        let promise: Promise<[BeamObjectType]> = objectManager.saveToAPI(objectsToSave)
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return promise.then(on: backgroundQueue) { remoteObjects -> Promise<[BeamObjectType]> in
            try self.persistChecksum(remoteObjects)
            return Promise(remoteObjects)
        }
    }

    @discardableResult
    func deleteFromBeamObjectAPI(_ id: UUID) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return objectManager.delete(id).then(on: backgroundQueue) { _ in true }
    }

    func deleteFromBeamObjectAPI(_ ids: [UUID]) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let promises: [Promise<Bool>] = ids.map {
            deleteFromBeamObjectAPI($0)
        }
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return all(promises).then(on: backgroundQueue) { _ in
            Promise(true)
        }
    }

    func deleteAllFromBeamObjectAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        return objectManager.deleteAll(BeamObjectType.beamObjectTypeName)
    }

    func refreshFromBeamObjectAPI(_ object: BeamObjectType,
                                  _ forced: Bool = false) -> Promise<BeamObjectType?> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        guard !forced else {
            return objectManager.fetchObject(object).then(on: backgroundQueue) {
                Promise($0)
            }
        }

        return objectManager.fetchObjectUpdatedAt(object).then(on: backgroundQueue) { updatedAt -> Promise<BeamObjectType?> in
            guard let updatedAt = updatedAt, updatedAt > object.updatedAt else {
                return Promise(nil)
            }

            return objectManager.fetchObject(object).then(on: backgroundQueue) {
                Promise($0)
            }
        }
    }

    func fetchAllFromBeamObjectAPI() -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()

        return objectManager.fetchAllObjects()
    }

    func saveOnBeamObjectAPI(_ object: BeamObjectType) -> Promise<BeamObjectType> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(APIRequestError.notAuthenticated)
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        let promise: Promise<BeamObjectType> = objectManager.saveToAPI(object)

        return promise.then(on: backgroundQueue) { remoteObject -> Promise<BeamObjectType> in
            try self.persistChecksum([remoteObject])
            return Promise(remoteObject)
        }
    }
}
