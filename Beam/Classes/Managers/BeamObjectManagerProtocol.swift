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

    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType]) throws {
        guard !objects.isEmpty else { return }

        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        try self.saveOnBeamObjectsAPI(objects) { result in
            switch result {
            case .failure(let returnedError):
                Logger.shared.logError(returnedError.localizedDescription, category: .beamObjectNetwork)
                error = returnedError
            case .success:
                Logger.shared.logDebug("Saved \(objects)", category: .beamObjectNetwork)
            }
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
        if case .timedOut = semaphoreResult {
            Logger.shared.logError("Semaphore timedout", category: .beamObjectNetwork)
        }

        if let error = error { throw error }
    }

    @discardableResult
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              _ conflictPolicyForSave: BeamObjectConflictResolution = .replace,
                              _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) throws -> URLSessionTask? {
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

                if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error {
                    self.manageInvalidChecksum(error, completion)
                    return
                }

                // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
                guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
                    completion(.failure(error))
                    return
                }

                self.manageMultipleErrors(objectsToSave, errors, completion)

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
    func deleteFromBeamObjectAPI(_ id: UUID,
                                 _ completion: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        return try objectManager.delete(id) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success: completion(.success(true))
            }
        }
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity
    func refreshFromBeamObjectAPI(_ object: BeamObjectType,
                                  _ forced: Bool = false,
                                  _ completion: @escaping ((Swift.Result<BeamObjectType?, Error>) -> Void)) throws -> URLSessionDataTask {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        guard !forced else {
            return try objectManager.fetchObject(object) { result in
                switch result {
                case .failure(let error):
                    if case APIRequestError.notFound = error {
                        completion(.success(nil))
                        return
                    }
                    completion(.failure(error))
                case .success(let remoteObject): completion(.success(remoteObject))
                }
            }
        }

        return try objectManager.fetchObjectUpdatedAt(object) { result in
            switch result {
            case .failure(let error):
                if case APIRequestError.notFound = error {
                    completion(.success(nil))
                    return
                }

                completion(.failure(error))
            case .success(let updatedAt):
                guard let updatedAt = updatedAt, updatedAt > object.updatedAt else {
                    completion(.success(nil))
                    return
                }

                do {
                    _ = try objectManager.fetchObject(object) { result in
                        switch result {
                        case .failure(let error): completion(.failure(error))
                        case .success(let remoteObject):
                            completion(.success(remoteObject))
                        }
                    }
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
                guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error else {
                    completion(.failure(error))
                    return
                }

                self.manageInvalidChecksum(error) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let objects):
                        guard let newObject = objects.first, objects.count == 1 else {
                            completion(.failure(BeamObjectManagerDelegateError.runtimeError("Had more than one object back")))
                            return
                        }

                        do {
                            try self.persistChecksum([newObject])
                            completion(.success(newObject))
                        } catch {
                            completion(.failure(error))
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

    func manageInvalidChecksum(_ error: Error,
                               _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) {
        // Early return except for checksum issues.
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects,
                                                                                let goodObjects,
                                                                                let remoteObjects) = error else {
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

                        var allObjects: [BeamObjectType] = []
                        allObjects.append(contentsOf: goodObjects)
                        allObjects.append(contentsOf: remoteObjects)

                        Logger.shared.logDebug("⚠️ allObjects Objects", category: .beamObjectNetwork)
                        dump(allObjects)

                        try self.saveObjectsAfterConflict(remoteObjects)
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
    func manageMultipleErrors(_ objects: [BeamObjectType],
                              _ errors: [Error],
                              _ completion: @escaping ((Swift.Result<[BeamObjectType], Error>) -> Void)) {

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
                completion(.failure(BeamObjectManagerError.multipleErrors(errors)))
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
