import Foundation
import BeamCore

/// How do you want to resolve checksum conflicts
enum BeamObjectConflictResolution {
    /// Overwrite remote object with values from local object
    case replace

    /// Raise invalidChecksum error, which will include remote object, sent object, and potentially other good objects if any
    case fetchRemoteAndError
}

class BeamObjectManager {
    static var managerInstances: [String: BeamObjectManagerDelegateProtocol] = [:]
    static var translators: [String: (BeamObjectManagerDelegateProtocol, [BeamObject]) throws -> Void] = [:]

    static var networkRequests: [UUID: APIRequest] = [:]
    static var networkRequestsSemaphore = DispatchSemaphore(value: 1)

    #if DEBUG
    static var networkRequestsWithoutID: [APIRequest] = []
    #endif

    var webSocketRequest = APIWebSocketRequest()

    let backgroundQueue = DispatchQueue(label: "BeamObjectManager backgroundQueue", qos: .userInitiated)

    static func register<M: BeamObjectManagerDelegateProtocol, O: BeamObjectProtocol>(_ manager: M, object: O.Type) {
        managerInstances[object.beamObjectTypeName] = manager

        /*
         Translators is a way to know what object type is being processed by the manager
         */
        translators[object.beamObjectTypeName] = { manager, objects in

            let encapsulatedObjects: [O] = try objects.map {
                do {
                    var result: O = try $0.decodeBeamObject()

                    // Setting previousChecksum so code not doing anything more than storing objects/replacing existing objects
                    // at least doesn't break the sync and delta sync.
                    result.previousChecksum = result.checksum

                    return result
                } catch {
                    Logger.shared.logError("Error decoding \($0.beamObjectType) beamobject: \(error.localizedDescription)",
                                           category: .beamObject)
                    dump($0)
                    throw error
                }
            }

            try manager.parse(objects: encapsulatedObjects)
        }
    }

    static func unregisterAll() {
        managerInstances = [:]
        translators = [:]
    }

    static func setup() {
        // Add any manager using BeamObjects here
        DocumentManager().registerOnBeamObjectManager()
        DatabaseManager().registerOnBeamObjectManager()
        PasswordManager.shared.registerOnBeamObjectManager()
        BeamFileDBManager.shared.registerOnBeamObjectManager()
        BrowsingTreeStoreManager.shared.registerOnBeamObjectManager()
    }

    var conflictPolicyForSave: BeamObjectConflictResolution = .replace

    internal func filteredObjects(_ beamObjects: [BeamObject]) -> [String: [BeamObject]] {
        let filteredObjects: [String: [BeamObject]] = beamObjects.reduce(into: [:]) { result, object in
            result[object.beamObjectType] = result[object.beamObjectType] ?? []
            result[object.beamObjectType]?.append(object)
        }

        return filteredObjects
    }

    internal func parseFilteredObjectChecksums(_ filteredObjects: [String: [BeamObject]]) throws -> [String: [BeamObject]] {
        var results: [String: [BeamObject]] = [:]

        for (key, objects) in filteredObjects {
            guard let managerInstance = Self.managerInstances[key] else {
                Logger.shared.logDebug("**managerInstance for \(key) not found** keys: \(Self.managerInstances.keys)",
                                       category: .beamObject)
                continue
            }

            let checksums = try managerInstance.checksumsForIds(objects.map { $0.id })

            let changedObjects = objects.filter { $0.dataChecksum != checksums[$0.id] }
            results[key] = changedObjects
        }

        return results
    }

    internal func parseFilteredObjects(_ filteredObjects: [String: [BeamObject]]) throws {
        var objectsInErrors: Set<String> = Set()

        for (key, objects) in filteredObjects {
            guard let managerInstance = Self.managerInstances[key] else {
                Logger.shared.logDebug("**managerInstance for \(key) not found** keys: \(Self.managerInstances.keys)",
                                       category: .beamObject)
                continue
            }

            guard let translator = Self.translators[key] else {
                Logger.shared.logDebug("**translator for \(key) not found** keys: \(Self.translators.keys)",
                                       category: .beamObject)
                continue
            }

            do {
                try translator(managerInstance, objects)
            } catch {
                Logger.shared.logError("Error parsing remote \(key) beamobjects: \(error.localizedDescription). Retrying one by one.",
                                       category: .beamObjectNetwork)

                var objectsInError: [BeamObject] = []

                // When error occurs, we need to know what object is actually failing
                for beamObject in objects {
                    do {
                        try translator(managerInstance, [beamObject])
                    } catch {
                        objectsInError.append(beamObject)
                        objectsInErrors.insert(beamObject.beamObjectType)
                    }
                }

                var message: String
                if objectsInError.count == objects.count {
                    Logger.shared.logError("All \(key) objects in error", category: .beamObjectNetwork)
                    message = "All BeamObjects types: \(key) are in error"
                } else {
                    Logger.shared.logError("Error parsing following \(key) beamobjects: \(objectsInError.map { $0.id.uuidString }.joined(separator: ", "))",
                                           category: .beamObjectNetwork)
                    dump(objectsInError)
                    message = "Some BeamObjects types: \(key) are in error"
                }

                throw BeamObjectManagerError.parsingError(message)
            }
        }
    }

    internal func extractGoodObjects<T: BeamObjectProtocol>(_ objects: [T],
                                                            _ conflictedObject: T,
                                                            _ remoteBeamObjects: [BeamObject]) -> [T] {
        // Set `checksum` on the objects who were saved successfully as this will be used later
        objects.compactMap {
            if conflictedObject.beamObjectId == $0.beamObjectId { return nil }

            var remoteObject = $0
            remoteObject.checksum = remoteBeamObjects.first(where: {
                $0.id == remoteObject.beamObjectId
            })?.dataChecksum

            return remoteObject
        }
    }

    internal func extractGoodObjects<T: BeamObjectProtocol>(_ objects: [T],
                                                            _ objectErrorIds: [String],
                                                            _ remoteBeamObjects: [BeamObject]) -> [T] {
        // Set `checksum` on the objects who were saved successfully as this will be used later
        objects.compactMap {
            if objectErrorIds.contains($0.beamObjectId.uuidString.lowercased()) { return nil }

            var remoteObject = $0
            remoteObject.checksum = remoteBeamObjects.first(where: {
                $0.id == remoteObject.beamObjectId
            })?.dataChecksum

            return remoteObject
        }
    }

    internal func beamObjectsToObjects<T: BeamObjectProtocol>(_ beamObjects: [BeamObject]) throws -> [T] {
        var errors: [Error] = []
        let remoteObjects: [T] = try beamObjects.compactMap { beamObject in
            // Check if you have the same IDs for 2 different object types
            guard beamObject.beamObjectType == T.beamObjectTypeName else {
                // This is an important fail, we throw now
                let error = BeamObjectManagerDelegateError.runtimeError("returned object \(beamObject) \(beamObject.id) is not a \(T.beamObjectTypeName).")
                throw error
            }

            do {
                let remoteObject: T = try beamObject.decodeBeamObject()
                return remoteObject
            } catch {
                errors.append(BeamObjectManagerError.decodingError(beamObject))
            }

            return nil
        }

        guard errors.isEmpty else { throw BeamObjectManagerError.multipleErrors(errors) }

        return remoteObjects
    }

    internal func fetchObject<T: BeamObjectProtocol>(_ object: T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>!

        try fetchObject(object) { fetchObjectResult in
            result = fetchObjectResult
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(30))
        if case .timedOut = semaphoreResult {
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object, timedout")
        }

        switch result {
        case .failure(let error): throw error
        case .success(let object): return object
        case .none:
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object, got none!")
        }
    }

    internal func manageConflict<T: BeamObjectProtocol>(_ object: T,
                                                        _ remoteObject: T) -> T {
        var result = object

        if remoteObject.updatedAt > object.updatedAt {
            result = remoteObject
        }

        result.previousChecksum = remoteObject.checksum
        return result
    }

    internal func manageConflict(_ object: BeamObject,
                                 _ remoteObject: BeamObject) -> BeamObject {
        var result = object

        if let objectUpdatedAt = object.updatedAt,
           let remoteUpdatedAt = remoteObject.updatedAt,
           remoteUpdatedAt > objectUpdatedAt {
            result = remoteObject
        }

        result.previousChecksum = remoteObject.dataChecksum
        return result
    }
}
