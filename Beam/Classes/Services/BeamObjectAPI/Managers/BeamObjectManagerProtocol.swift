import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    static var conflictPolicy: BeamObjectConflictResolution { get }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<(Int, Date?), Error>) -> Void)) throws -> APIRequest?

    // Called when we want to check checksums for existing IDS
    func checksumsForIds(_ ids: [UUID]) throws -> [UUID: String]
}

protocol BeamObjectManagerDelegate: AnyObject, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    func registerOnBeamObjectManager()

    /// When new objects have been received and should be stored locally by the manager
    func receivedObjects(_ objects: [BeamObjectType]) throws

    /// Needed to store checksum and resend them in a future network request
    func persistChecksum(_ objects: [BeamObjectType]) throws

    /// Returns all objects, used to save all of them as beam objects
    func allObjects(updatedSince: Date?) throws -> [BeamObjectType]

    /// Will be called before savingAll objects
    func willSaveAllOnBeamObjectApi()

    /// When doing manual conflict management. `object` and `remoteObject` can be the same if the conflict was only
    /// because of a checksum issue, when we locally have stored previousChecksum but it's been deleted on the server
    /// side
    /// You only need to use this when you have manual conflict management, see `DocumentManager` for an example of how to implement it, and
    /// `DatabaseManager` if you don't handle conflict manually
    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType

    /// When a conflict happens, we will resend a potentially updated version and should store its result without trying to merge in a smart way
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws
}

enum BeamObjectManagerDelegateError: Error {
    case runtimeError(String)
    case nestedTooDeep
}

extension BeamObjectManagerDelegateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let text):
            return text
        case .nestedTooDeep:
            return "Nested too deep"
        }
    }
}

extension BeamObjectManagerDelegate {
    func registerOnBeamObjectManager() {
        BeamObjectManager.register(self, object: BeamObjectType.self)
    }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws {
        guard let parsedObjects = objects as? [BeamObjectType] else {
            return
        }

        var objectIds = objects.map { $0.beamObjectId.uuidString.lowercased() }
        if objectIds.count > 10 {
            objectIds = Array(objectIds[0...10])
            objectIds.append("...")
        }

        Logger.shared.logDebug("Received \(parsedObjects.count) \(T.beamObjectTypeName): \(objectIds)",
                               category: .beamObjectNetwork)
        let localTimer = BeamDate.now

        try receivedObjects(parsedObjects)
        self.checkPreviousChecksums(parsedObjects)

        Logger.shared.logDebug("Received \(parsedObjects.count) \(T.beamObjectTypeName). Manager done",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)
    }

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) throws {
        guard !objects.isEmpty else { return }

        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        try self.saveOnBeamObjectsAPI(objects) { result in
            switch result {
            case .failure(let returnedError):
                Logger.shared.logError("Can't save: \(returnedError.localizedDescription)", category: .beamObjectNetwork)
                error = returnedError
            case .success:
                Logger.shared.logDebug("Saved \(objects.count) objects", category: .beamObjectNetwork)
            }
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(30))
        if case .timedOut = semaphoreResult {
            Logger.shared.logError("Semaphore timedout", category: .beamObjectNetwork)
        }

        if let error = error { throw error }
    }

    /*
     This is a check to see if beam object managers store previousChecksum properly and raise errors asap when someone
     is adding a new object type to be stored on the API.

     Potentially slow, might make that faster?

     */
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func checkPreviousChecksums(_ remoteObjects: [BeamObjectType]) {
        #if DEBUG
        do {
            let savedObjects = try self.allObjects(updatedSince: nil)
            var wrongObjects: [BeamObjectType] = []
            for remoteObject in remoteObjects {
                guard let savedObject = savedObjects.first(where: {
                    $0.beamObjectId == remoteObject.beamObjectId
                }) else { continue }

                if savedObject.previousChecksum != remoteObject.previousChecksum {
                    wrongObjects.append(remoteObject)
                }
            }

            guard !wrongObjects.isEmpty else { return }
            Logger.shared.logWarning("\(wrongObjects.count) objects had wrong checksum after save, checking on the API if they've been updated since",
                                     category: .beamObjectNetwork)
            let beamObjectManager = BeamObjectManager()
            try beamObjectManager.fetchBeamObjectChecksums(wrongObjects.map { $0.beamObjectId }) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                case .success(let remoteBeamObjects):
                    var diffObjects: [BeamObjectType] = []

                    for remoteObject in remoteObjects {
                        guard let savedObject = savedObjects.first(where: {
                            $0.beamObjectId == remoteObject.beamObjectId
                        }) else { continue }

                        guard let remoteBeamObject = remoteBeamObjects.first(where: {
                            $0.id == remoteObject.beamObjectId
                        }) else { continue }

                        if savedObject.previousChecksum != remoteBeamObject.dataChecksum {
                            diffObjects.append(savedObject)
                        }
                    }

                    guard !diffObjects.isEmpty else { return }

                    for remoteObject in remoteObjects {
                        guard let savedObject = savedObjects.first(where: {
                            $0.beamObjectId == remoteObject.beamObjectId
                        }) else { continue }

                        guard let remoteBeamObject = remoteBeamObjects.first(where: {
                            $0.id == remoteObject.beamObjectId
                        }) else { continue }

                        if savedObject.previousChecksum != remoteObject.previousChecksum {
                            Logger.shared.logWarning("previousChecksum for object \(remoteObject.beamObjectId) wasn't saved in local object. Remote: \(String(describing: remoteObject.previousChecksum)), local: \(String(describing: savedObject.previousChecksum)), New remote: \(String(describing: remoteBeamObject.dataChecksum))", category: .beamObjectNetwork)
                        }
                    }
                    fatalError("previousChecksum for objects is wrong!")
                }
            }
        } catch { fatalError("Failed: \(error.localizedDescription)") }
        #endif
    }
}
