import Foundation
import BeamCore

protocol BeamObjectManagerDelegateProtocol {
    func parse<T: BeamObjectProtocol>(objects: [T]) throws

    // Called when `BeamObjectManager` wants to store all existing `Document` as `BeamObject`
    // it will call this method
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask?
}

protocol BeamObjectManagerDelegate: class, BeamObjectManagerDelegateProtocol {
    associatedtype BeamObjectType: BeamObjectProtocol
    func registerOnBeamObjectManager()

    // When new objects have been received and should be stored locally by the manager
    func receivedObjects(_ objects: [BeamObjectType]) throws

    // Needed to store checksum and resend them in a future network request
    func persistChecksum(_ objects: [BeamObjectType], _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws

    // Returns all objects, used to save all of them as beam objects
    func allObjects() throws -> [BeamObjectType]

    // When doing manual conflict management
    func manageConflict(_ object: BeamObjectType,
                        _ remoteBeamObject: BeamObject,
                        _ error: Error) throws -> BeamObjectType
}

enum BeamObjectManagerDelegateError: Error {
    case runtimeError(String)
}

extension BeamObjectManagerDelegate {
    func registerOnBeamObjectManager() {
        BeamObjectManager.register(self, object: BeamObjectType.self)
    }

    func parse<T: BeamObjectProtocol>(objects: [T]) throws {
        guard let parsedObjects = objects as? [BeamObjectType] else {
            return
        }

        try receivedObjects(parsedObjects)
    }

    func manageConflict(_ object: BeamObjectType,
                        _ remoteBeamObject: BeamObject,
                        _ error: Error) throws -> BeamObjectType {
        throw BeamObjectManagerDelegateError.runtimeError("manageConflict must be implemented by the class")
    }

    func updatedObjectsOnly(_ objects: [BeamObjectType]) -> [BeamObjectType] {
        objects.filter {
            $0.previousChecksum != $0.checksum || $0.previousChecksum == nil
        }
    }

    func saveAllOnBeamObjectApi(_ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        return try saveOnBeamObjectsAPI(try allObjects(), .replace, completion)
    }

    @discardableResult
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              _ conflictPolicyForSave: BeamObjectConflictResolution = .replace,
                              _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectsToSave = updatedObjectsOnly(objects)

        guard !objectsToSave.isEmpty else {
            completion(.success(true))
            return nil
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = conflictPolicyForSave

        return try objectManager.saveToAPI(objectsToSave) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save all \(objectsToSave): \(error.localizedDescription)",
                                       category: .databaseNetwork)

                switch conflictPolicyForSave {
                case .replace:
                    completion(.failure(error))
                case .fetchRemoteAndError:
                    self.manageConflictAndSave(objectsToSave, error, completion)
                }
            case .success(let remoteObjects):
                do {
                    try self.persistChecksum(remoteObjects, completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func saveOnBeamObjectAPIFailure(_ object: BeamObjectType,
                                    _ error: Error,
                                    _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        // Early return except for checksum issues.
        guard case BeamObjectManagerError.invalidChecksum = error else {
            completion(.failure(error))
            return
        }

        // This should never be called since invalid checksum are managed inside BeamObjectManager
        assert(false)
    }

    @discardableResult
    func saveOnBeamObjectAPI(_ object: BeamObjectType,
                             _ conflictPolicyForSave: BeamObjectConflictResolution = .replace,
                             _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = conflictPolicyForSave

        // TODO: Race conditions, add semaphore
//        Self.networkTasks[databaseStruct.id]?.cancel()

        let networkTask = try objectManager.saveToAPI(object) { result in
            switch result {
            case .failure(let error):
                switch conflictPolicyForSave {
                case .replace:
                    completion(.failure(error))
                case .fetchRemoteAndError:
                    self.manageConflictAndSave(object, error, completion)
                }

            case .success(let remoteObject):
                do {
                    try self.persistChecksum([remoteObject], completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }

//        Self.networkTasks[databaseStruct.id] = networkTask

        return networkTask
    }

    func manageConflictAndSave(_ object: BeamObjectType,
                               _ error: Error,
                               _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        // Early return except for checksum issues.
        guard case BeamObjectManagerError.invalidChecksum(let remoteBeamObject) = error else {
            completion(.failure(error))
            return
        }

        do {
            // Checksum issue, the API side of the object was updated since our last fetch
            let mergedObject = try manageConflict(object, remoteBeamObject, error)

            try self.saveOnBeamObjectAPI(mergedObject, .fetchRemoteAndError, completion)
        } catch {
            completion(.failure(error))
        }
    }

    func manageConflictAndSave(_ objects: [BeamObjectType],
                               _ error: Error,
                               _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        // This case happens when we use the network call to send multiple documents,
        // but only send 1 and have an invalid checksum
        if case BeamObjectManagerError.invalidChecksum = error,
           let object = objects.first {
            manageConflictAndSave(object, error, completion)
            return
        }

        // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
        guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
            completion(.failure(error))
            return
        }

        var newObjects: [BeamObjectType] = []
        for insideError in errors {
            /*
             We have multiple errors. If all errors are about invalid checksums, we can fix and retry. Else we'll just
             stop and call the completion handler with the original error
             */
            guard case BeamObjectManagerError.invalidChecksum(let remoteObject) = insideError else {
                completion(.failure(error))
                return
            }

            // Here we should try to merge remoteBeamObject converted as a DocumentStruct, and our local one.
            // For now we just overwrite the API with our local version with a batch call resending all of them
            guard let object = objects.first(where: { $0.beamObjectId == remoteObject.beamObjectId }) else {
                Logger.shared.logError("Could not save: \(insideError.localizedDescription)",
                                       category: .documentNetwork)
                Logger.shared.logError("No ID :( for \(remoteObject.id)", category: .documentNetwork)
                continue
            }

            do {
                let mergedObject = try manageConflict(object, remoteObject, insideError)
                newObjects.append(mergedObject)
            } catch {
                completion(.failure(error))
                return
            }
        }

        do {
            try self.saveOnBeamObjectsAPI(newObjects, .fetchRemoteAndError, completion)
        } catch {
            completion(.failure(error))
        }
    }
}
