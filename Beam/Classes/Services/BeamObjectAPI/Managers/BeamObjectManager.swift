import Foundation
import BeamCore
import Atomics
import Combine

/// How do you want to resolve checksum conflicts
enum BeamObjectConflictResolution {
    /// Overwrite remote object with values from local object
    case replace

    /// Raise invalidChecksum error, which will include remote object, sent object, and potentially other good objects if any
    case fetchRemoteAndError
}

enum BeamObjectRequestUploadType {
    case directUpload
    case multipartUpload
}

// Add your object type when saving over the beam object API
enum BeamObjectObjectType: String {
    case password
    case creditCard
    case link
    case database
    case browsingTree = "browsing_tree"
    case file
    case document
    case myRemoteObject = "my_remote_object"
    case contact
    case noteFrecency = "note_frecency"
    case privateKeySignature
    case tabGroup

    static func fromString(value: String) -> Self? {
        BeamObjectObjectType(rawValue: value)
    }
}

enum BeamObjectObjectSynchronizationStatus: CustomStringConvertible {
    case notStarted
    case downloading(Float)
    case uploading(Float)
    case finished
    case failure(Error)

    var description: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .downloading(let progress):
            let formattedProgress = String(format: "%.0f%%", progress)
            return "Downloading \(formattedProgress)"
        case .uploading(let progress):
            let formattedProgress = String(format: "%.0f%%", progress)
            return "Uploading \(formattedProgress)"
        case .finished:
            return "Finished"
        case .failure(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

public final class BeamObjectManager {
    var managerOrder: [BeamObjectObjectType] = []
    var managerInstances: [BeamObjectObjectType: BeamObjectManagerDelegateProtocol] = [:]
    var translators: [BeamObjectObjectType: (BeamObjectManagerDelegateProtocol, [BeamObject]) throws -> Void] = [:]
    var uploadTypeForTests: BeamObjectRequestUploadType?
    var disableSendingObjects = true

    let lock = NSLock()
    var fullSyncRunning = false

    var synchronizationStatusSubject = CurrentValueSubject<BeamObjectObjectSynchronizationStatus, Never>(.notStarted)
    var synchronizationStatus: BeamObjectObjectSynchronizationStatus {
        get {
            synchronizationStatusSubject.value
        }
        set {
            synchronizationStatusSubject.value = newValue
        }
    }

    #if DEBUG
    var networkRequests: [APIRequest] = []
    #endif

    var webSocketRequest: APIWebSocketRequest?
    var websocketRetryDelay = 0

    func register<M: BeamObjectManagerDelegateProtocol, O: BeamObjectProtocol>(_ manager: M, object: O.Type) {
        managerInstances[object.beamObjectType] = manager

        /*
         Translators is a way to know what object type is being processed by the manager
         */
        translators[object.beamObjectType] = { manager, objects in
            let previousChecksums = BeamObjectChecksum.previousChecksums(beamObjects: objects)

            var localTimer = Date()

            // Any received object with the same content than the one we already sent is skipped
            let toSaveObjects: [BeamObject] = {
                // Skip the check if no previous stored checksums at all meaning it's a first sync
                guard !previousChecksums.isEmpty else { return objects }

                return objects.compactMap {
                    // previous stored checksum is the same as the temote data checksum, we can skip
                    if previousChecksums[$0] == $0.dataChecksum {
                        return nil
                    }
                    return $0
                }
            }()

            Logger.shared.logDebug("Received \(objects.count) \(object.beamObjectType), filtered to \(toSaveObjects.count) after checksum verification. \(previousChecksums.count) existing checksums",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)

            localTimer = Date()

            var totalSize: Int64 = 0

            if toSaveObjects.count > 1000 {
                Logger.shared.logDebug("Decoding \(toSaveObjects.count) BeamObject",
                                       category: .beamObjectNetwork)
            }

            let encapsulatedObjects: [O] = try toSaveObjects.filter { $0.data != nil }.map {
                do {
                    let result: O = try $0.decodeBeamObject()
                    totalSize += Int64($0.data?.count ?? 0)

                    // Setting previousChecksum so code not doing anything more than storing objects/replacing existing objects
                    // at least doesn't break the sync and delta sync.
//                    result.previousChecksum = result.checksum

                    return result
                } catch {
                    Logger.shared.logError("Error decoding \($0.beamObjectType) beamobject: \(error)",
                                           category: .beamObject)
                    dump($0)
                    throw error
                }
            }

            Logger.shared.logDebug("Decoded \(toSaveObjects.count) BeamObject to \(O.beamObjectType)",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)

            localTimer = Date()

            /*
             IMPORTANT: code inside `parse` and the manager, outside the area of `BeamObjectManager`
             might call `saveOnAPI()` to save objects. Ex: when database with same titles arrive and it's being changed +
             resaved on the API. It needs to have `previousChecksum` already available to avoid conflicts.

             We must therefor save object's previousChecksums *before* calling the manager.
             */

            _ = try BeamObjectChecksum.savePreviousChecksums(beamObjects: toSaveObjects)

            do {
                try manager.parse(objects: encapsulatedObjects)
            } catch {
                /*
                 We had issues saving those, we *must* delete previous checksums attached to those objects else a new
                 fetch will not fetch those objects again, as the local checksum will be equal to remote ones.

                 The error might be temporary and we should fetch those again.

                 TODO: we should only delete checksums of failed objects, but we don't currently have a way to know about
                 successful object saves and failed ones. We will therefor refetch successful objects in case of failures.
                 */
                try BeamObjectChecksum.deletePreviousChecksums(beamObjects: toSaveObjects)
                throw error
            }

            _ = try BeamObjectChecksum.savePreviousObjects(beamObjects: toSaveObjects)

            Logger.shared.logDebug("Received \(encapsulatedObjects.count) \(object.beamObjectType) (\(totalSize.byteSize)). Manager done",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
        }
    }

    func unregister(objectType: BeamObjectObjectType) {
        managerInstances.removeValue(forKey: objectType)
    }

    func unregisterAll() {
        managerInstances = [:]
        translators = [:]
    }

    func setup() {
        let treeSyncEnabled = Configuration.browsingTreeApiSyncEnabled

        /*
         Not yet used: In what order should we proceed when receiving new objects? We might have objects with
         dependencies. Ex: `Document` needs `Database`.

         We should use that order when sending objects to the API, and when receiving new objects.
         */
        managerOrder = [.privateKeySignature, .database, .contact, .file, .tabGroup, .document, .password, .link, .noteFrecency]
        if treeSyncEnabled {
            managerOrder.append(.browsingTree)
        }

        if managerOrder.count != managerInstances.count {
            Logger.shared.logError("Wrong number of BeamObjectManagers. Should be \(managerOrder.count): \(managerOrder)\nbut had \(managerInstances.count): \(managerInstances.values)", category: .beamObjectDebug)
        }
    }

    func filteredObjects(_ beamObjects: [BeamObject]) -> [BeamObjectObjectType: [BeamObject]] {
        let filteredObjects: [BeamObjectObjectType: [BeamObject]] = beamObjects.reduce(into: [:]) { result, object in
            if let beamObjectType = BeamObjectObjectType.fromString(value: object.beamObjectType) {
                result[beamObjectType] = result[beamObjectType] ?? []
                result[beamObjectType]?.append(object)
            } else {
                Logger.shared.logWarning("Found \(object.beamObjectType) but can't process this type",
                                         category: .beamObject)
            }
        }

        return filteredObjects
    }

    func parseObjectChecksums(_ objects: [BeamObject]) -> [BeamObject] {
        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: objects)

        let changedObjects = objects.filter {
            $0.dataChecksum != checksums[$0] || checksums[$0] == nil
        }

        return changedObjects
    }

    func parseFilteredObjects(_ filteredObjects: [BeamObjectObjectType: [BeamObject]]) throws {
        var objectsInErrors: Set<String> = Set()

        var errors: [Error] = []

        let localTimer = Date()
        Logger.shared.logDebug("Call object managers: start",
                               category: .beamObject)

        /*
         IMPORTANT: we might receive a bunch of objects at once (initial sync) and parsing all of the types in parallels
         might raise issues, as `document` objects need their `database`. Bug if done in parallel would be resaving
         the database object on the API without having its local checksum saved yet.

         BeamObjects don't have dependencies map, therefor we don't know which ones we should proceed first. As a quick
         fix I will parse per type, in the order listed at `managerOrder`.
         */

        let sortedObjects = filteredObjects.sorted(by: {
            if let firstIndex = managerOrder.firstIndex(of: $0.0), let secondIndex = managerOrder.firstIndex(of: $1.0) {
                return firstIndex < secondIndex
            }
            return true
        })

        for (key, objects) in sortedObjects {
            guard let managerInstance = managerInstances[key] else {
                Logger.shared.logDebug("**managerInstance for \(key) not found** keys: \(managerInstances.keys)",
                                       category: .beamObject)
                continue
            }

            guard let translator = translators[key] else {
                Logger.shared.logDebug("**translator for \(key) not found** keys: \(translators.keys)",
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
                    message = "All \(objectsInError.count) BeamObjects types: \(key) are in error"
                    dump(objectsInError)
                } else {
                    Logger.shared.logError("Error parsing following \(key) beamobjects: \(objectsInError.map { $0.id.uuidString }.joined(separator: ", "))",
                                           category: .beamObjectNetwork)
                    dump(objectsInError)
                    message = "Some BeamObjects types: \(key) are in error"
                }
                DispatchQueue.mainSync {
                    errors.append(BeamObjectManagerError.parsingError(message))
                }
            }
        }

        Logger.shared.logDebug("Call object managers: done",
                               category: .beamObject,
                               localTimer: localTimer)

        if !errors.isEmpty {
            throw BeamObjectManagerError.multipleErrors(errors)
        }
    }

    func extractGoodObjects<T: BeamObjectProtocol>(_ objects: [T],
                                                            _ conflictedObject: T) -> [T] {
        // Set `checksum` on the objects who were saved successfully as this will be used later
        objects.compactMap {
            if conflictedObject.beamObjectId == $0.beamObjectId { return nil }

            return $0
        }
    }

    func extractGoodObjects<T: BeamObjectProtocol>(_ objects: [T],
                                                            _ objectErrorIds: [String],
                                                            _ remoteBeamObjects: [BeamObject]) -> [T] {
        // Set `checksum` on the objects who were saved successfully as this will be used later
        objects.compactMap {
            if objectErrorIds.contains($0.beamObjectId.uuidString.lowercased()) { return nil }

            return $0
        }
    }

    func beamObjectsToObjects<T: BeamObjectProtocol>(_ beamObjects: [BeamObject]) throws -> [T] {
        var errors: [Error] = []
        let remoteObjects: [T] = try beamObjects.compactMap { beamObject in
            // Check if you have the same IDs for 2 different object types
            guard beamObject.beamObjectType == T.beamObjectType.rawValue else {
                // This is an important fail, we throw now
                let error = BeamObjectManagerDelegateError.runtimeError("returned object \(beamObject) \(beamObject.id) is not a \(T.beamObjectType).")
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

    func manageConflict<T: BeamObjectProtocol>(_ object: T, _ remoteObject: T) -> T {
        var result = object

        // Fetch the most recent
        if remoteObject.updatedAt > object.updatedAt {
            result = remoteObject
        }

        return result
    }

    func manageConflict(_ object: BeamObject, _ remoteObject: BeamObject) -> BeamObject {
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

// MARK: - BeamObjectProtocol
func updatedObjectsOnly(_ beamObjects: [BeamObject]) -> [BeamObject] {
    let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

    return beamObjects.filter {
        checksums[$0] != $0.dataChecksum || checksums[$0] == nil
    }
}

