import Foundation
import PromiseKit
import BeamCore

extension BeamObjectManager {
    func syncAllFromAPI(delete: Bool = true) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let promise: Promise = fetchAllFromAPI()

        return promise

//        return promise.then(on: backgroundQueue) { _ in
//            // try self.saveAllToAPI()
//            return true
//        }
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        let promise: Promise = beamRequest.fetchAll(receivedAtAfter: lastReceivedAt)

        // TODO: add a way to cancel this request

        return promise.map(on: backgroundQueue) { beamObjects in
            guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
                return true
            }

            if let mostRecentReceivedAt = beamObjects.compactMap({ $0.updatedAt }).sorted().last {
                Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt). \(beamObjects.count) beam objects fetched.",
                                       category: .beamObjectNetwork)
                Logger.shared.logDebug("objects IDs: \(beamObjects.map { $0.id.uuidString.lowercased() }.joined(separator: ", "))",
                                       category: .beamObjectNetwork)
            }

            try self.parseObjects(beamObjects)

            return true
        }
    }
}

// MARK: - BeamObjectProtocol
extension BeamObjectManager {
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T]) -> Promise<[T]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        var beamObjects: [BeamObject]

        do {
            beamObjects = try objects.map {
                try BeamObject($0, T.beamObjectTypeName)
            }
        } catch {
            return Promise(error: error)
        }

        let promise: Promise = request.saveAll(beamObjects)
        // TODO: add a way to cancel request

        return promise.map(on: backgroundQueue) { remoteBeamObjects in
            // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
            // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
            // and set their `previousChecksum`
            // We'll use `copy()` when it's faster and doesn't encode/decode

            // Caller will need to store those previousCheckum into its data storage, we must return it
            let savedObjects: [T] = try beamObjects.map {
                var remoteObject: T = try $0.decodeBeamObject()
                remoteObject.previousChecksum = remoteBeamObjects.first(where: {
                    $0.id == remoteObject.beamObjectId
                })?.dataChecksum

                return remoteObject
            }

            return savedObjects
        }
    }

    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T]) -> Promise<[T]> {
        fetchBeamObjects(objects.map { $0.beamObjectId }).map(on: backgroundQueue) { remoteBeamObjects in
            try self.beamObjectsToObjects(remoteBeamObjects)
        }
    }

    @discardableResult
    internal func fetchBeamObjects(_ beamObjects: [BeamObject]) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()

        return request.fetchAll(ids: beamObjects.map { $0.id })
    }

    @discardableResult
    internal func fetchBeamObjects(_ ids: [UUID]) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()
        return request.fetchAll(ids: ids)
    }

    func saveToAPI<T: BeamObjectProtocol>(_ object: T) -> Promise<T> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        var beamObject: BeamObject

        do {
            beamObject = try BeamObject(object, T.beamObjectTypeName)
        } catch { return Promise(error: error) }

        let request = BeamObjectRequest()
        let promise: Promise = request.save(beamObject)

        return promise.map(on: backgroundQueue) { remoteBeamObject in
            // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
            // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
            // and set their `previousChecksum`

            // We'll use `copy()` when it's faster and doesn't encode/decode
            var savedObject: T = try beamObject.decodeBeamObject()
            savedObject.previousChecksum = remoteBeamObject.dataChecksum
            return savedObject
        }
    }

    /// Fetch remote object
    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T) -> Promise<T> {
        let promise = fetchBeamObject(object.beamObjectId)

        return promise.map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")
            }

            return try remoteBeamObject.decodeBeamObject()
        }
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(_ object: T) -> Promise<Date?> {
        fetchMinimalBeamObject(object.beamObjectId).map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")
            }
            return remoteBeamObject.updatedAt
        }
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(_ object: T) -> Promise<String?> {
        fetchMinimalBeamObject(object.beamObjectId).map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")
            }
            return remoteBeamObject.dataChecksum
        }
    }
}

// MARK: - BeamObject
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObject]) -> Promise<[BeamObject]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        let promise: Promise = request.saveAll(beamObjects)

        return promise.map(on: backgroundQueue) { updateBeamObjects in
            updateBeamObjects.map {
                let result = $0.copy()
                result.previousChecksum = $0.dataChecksum
                return result
            }
        }
    }

    func saveToAPI(_ beamObject: BeamObject) -> Promise<BeamObject> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        let promise: Promise = request.save(beamObject)

        return promise.map(on: backgroundQueue) { updateBeamObject in
            let savedBeamObject = updateBeamObject.copy()
            savedBeamObject.previousChecksum = updateBeamObject.dataChecksum
            return savedBeamObject
        }
    }

    internal func fetchBeamObject(_ beamObject: BeamObject) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetch(beamObject.id)
    }

    internal func fetchBeamObject(_ id: UUID) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetch(id)
    }

    internal func fetchMinimalBeamObject(_ id: UUID) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetchMinimalBeamObject(id)
    }

    func delete(_ id: UUID) -> Promise<BeamObject> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()

        return request.delete(id)
    }

    func deleteAll(_ beamObjectType: String? = nil) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        return request.deleteAll(beamObjectType: beamObjectType)
    }
}

