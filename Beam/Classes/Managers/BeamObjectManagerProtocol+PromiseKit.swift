import Foundation
import PromiseKit

/*
 Those are not yet ready to be used
 */
extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        self.willSaveAllOnBeamObjectApi()
        var objects: [BeamObjectType]
        do {
            objects = try allObjects()
        } catch {
            return Promise(error: error)
        }

        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
        return saveOnBeamObjectsAPI(objects).map(on: backgroundQueue) { _ in
            true
        }
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) -> Promise<[BeamObjectType]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: APIRequestError.notAuthenticated)
        }

        let objectsToSave = updatedObjectsOnly(objects)

        guard !objectsToSave.isEmpty else {
            return Promise.value([])
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        let promise: Promise<[BeamObjectType]> = objectManager.saveToAPI(objectsToSave)
        let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

        return promise.map(on: backgroundQueue) { remoteObjects in
            try self.persistChecksum(remoteObjects)
            return remoteObjects
        }
    }

    @discardableResult
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
        }
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
        }
    }
}
