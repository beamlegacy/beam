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
    func persistChecksum(_ objects: [BeamObjectType]) throws

    // Returns all objects, used to save all of them as beam objects
    func allObjects() throws -> [BeamObjectType]

    // When doing manual conflict management
    func manageConflict(_ object: BeamObjectType,
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType

    // When a conflict happens, we will resend a potentially updated version and should store its result
    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws
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
                        _ remoteObject: BeamObjectType) throws -> BeamObjectType {
        throw BeamObjectManagerDelegateError.runtimeError("manageConflict must be implemented by the class")
    }

    func saveObjectsAfterConflict(_ objects: [BeamObjectType]) throws {
        throw BeamObjectManagerDelegateError.runtimeError("saveObjectsAfterConflict must be implemented by the class")
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

        return try saveOnBeamObjectsAPI(try allObjects(), .replace) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success: completion(.success(true))
            }
        }
    }

    @discardableResult
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              _ conflictPolicyForSave: BeamObjectConflictResolution = .replace,
                              _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) throws -> URLSessionTask? {
        Logger.shared.logDebug("⚠️ inside saveOnBeamObjectsAPI", category: .beamObjectNetwork)

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectsToSave = updatedObjectsOnly(objects)

        guard !objectsToSave.isEmpty else {
            completion(.success([]))
            return nil
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = conflictPolicyForSave

        return try objectManager.saveToAPI(objectsToSave) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save all \(objectsToSave.count) objects: \(error.localizedDescription)",
                                       category: .databaseNetwork)

                switch conflictPolicyForSave {
                case .replace:
                    completion(.failure(error))
                case .fetchRemoteAndError:
                    Logger.shared.logDebug("⚠️ will call manageConflictAndSave", category: .beamObjectNetwork)

                    self.manageConflictAndSave(objectsToSave, error, completion)
                }
            case .success(let remoteObjects):
                do {
                    try self.persistChecksum(remoteObjects)
                    completion(.success(remoteObjects))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    @discardableResult
    func saveOnBeamObjectAPI(_ object: BeamObjectType,
                             _ conflictPolicyForSave: BeamObjectConflictResolution = .replace,
                             _ completion: @escaping ((Swift.Result<BeamObjectType, Error>) -> Void)) throws -> URLSessionTask? {
        Logger.shared.logDebug("⚠️ inside saveOnBeamObjectAPI", category: .beamObjectNetwork)

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
                    self.manageConflictAndSave(error) { result in
                        switch result {
                        case .failure(let error): completion(.failure(error))
                        case .success(let objects):
                            guard let newObject = objects.first, objects.count == 1 else {
                                completion(.failure(BeamObjectManagerDelegateError.runtimeError("Had more than one object back")))
                                return
                            }

                            completion(.success(newObject))
                        }
                    }
                }

            case .success(let remoteObject):
                do {
                    try self.persistChecksum([remoteObject])
                    completion(.success(remoteObject))
                } catch {
                    completion(.failure(error))
                }
            }
        }

//        Self.networkTasks[databaseStruct.id] = networkTask

        return networkTask
    }

    func manageConflictAndSave(_ error: Error,
                               _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) {
        // Early return except for checksum issues.
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects, let goodObjects, let remoteObjects) = error else {
            completion(.failure(error))
            return
        }

        do {
            var mergedObjects: [BeamObjectType] = []

            for conflictedObject in conflictedObjects {
                guard let remoteObject = remoteObjects.first(where: { $0.beamObjectId == conflictedObject.beamObjectId }) else {
                    Logger.shared.logError("Can't find the remote object connected to the conflict object!",
                                           category: .beamObject)
                    continue }

                var mergedObject = try manageConflict(conflictedObject, remoteObject)
                mergedObject.previousChecksum = remoteObject.checksum

                mergedObjects.append(mergedObject)
            }

            Logger.shared.logDebug("⚠️ merged Objects", category: .beamObjectNetwork)
            dump(mergedObjects)

            try self.saveOnBeamObjectsAPI(mergedObjects, .fetchRemoteAndError) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let remoteObjects):
                    do {
                        try self.saveObjectsAfterConflict(remoteObjects)

                        var allObjects: [BeamObjectType] = []
                        allObjects.append(contentsOf: goodObjects)
                        allObjects.append(contentsOf: remoteObjects)

                        Logger.shared.logDebug("⚠️ allObjects Objects", category: .beamObjectNetwork)
                        dump(allObjects)

                        try self.persistChecksum(goodObjects)

                        completion(.success(allObjects))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func manageConflictAndSave(_ objects: [BeamObjectType],
                               _ error: Error,
                               _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) {

        // This case happens when we use the network call to send multiple documents,
        // but only send 1 and have an invalid checksum
        if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects, let goodObjects, let remoteObjects) = error {
            Logger.shared.logDebug("⚠️ inside BeamObjectManagerObjectError", category: .beamObjectNetwork)

            Logger.shared.logDebug("⚠️ conflictedObjects: ", category: .beamObjectNetwork)
            dump(conflictedObjects)

            Logger.shared.logDebug("⚠️ goodObjects: ", category: .beamObjectNetwork)
            dump(goodObjects)

            Logger.shared.logDebug("⚠️ remoteObjects: ", category: .beamObjectNetwork)
            dump(remoteObjects)

            Logger.shared.logDebug("⚠️ objects: ", category: .beamObjectNetwork)
            dump(objects)

//            guard conflictedObjects.count == 1 else {
//                completion(.failure(BeamObjectManagerDelegateError.runtimeError("Had more than one object back")))
//                return
//            }

            manageConflictAndSave(error, completion)
            return
        }

        // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
        guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
            completion(.failure(error))
            return
        }

        var newObjects: [BeamObjectType] = []
        var goodObjects: [BeamObjectType] = []
        for insideError in errors {
            /*
             We have multiple errors. If all errors are about invalid checksums, we can fix and retry. Else we'll just
             stop and call the completion handler with the original error
             */
            guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects, let errorGoodObjects, let remoteObjects) = insideError else {
                completion(.failure(error))
                return
            }

            guard let conflictedObject = conflictedObjects.first, conflictedObjects.count == 1 else {
                completion(.failure(BeamObjectManagerDelegateError.runtimeError("Had more than one object back")))
                return
            }

            guard let remoteObject = remoteObjects.first, remoteObjects.count == 1 else {
                completion(.failure(BeamObjectManagerDelegateError.runtimeError("Had more than one object back")))
                return
            }

            do {
                var mergedObject = try manageConflict(conflictedObject, remoteObject)
                mergedObject.previousChecksum = remoteObject.checksum

                goodObjects.append(contentsOf: errorGoodObjects)
                newObjects.append(mergedObject)
            } catch {
                completion(.failure(error))
                return
            }
        }

        Logger.shared.logDebug("⚠️ inside manageConflictAndSave, will save multiple objects", category: .beamObjectNetwork)

        do {
            try self.saveOnBeamObjectsAPI(newObjects, .fetchRemoteAndError) { result in
                switch result {
                case .failure: completion(result)
                case .success(let newObjectsSaved):
                    do {
                        try self.saveObjectsAfterConflict(newObjectsSaved)

                        completion(.success(goodObjects + newObjectsSaved))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
