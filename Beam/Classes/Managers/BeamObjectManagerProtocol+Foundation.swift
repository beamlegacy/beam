import Foundation
import BeamCore

extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Result<(Int, Date?), Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        self.willSaveAllOnBeamObjectApi()

        let toSaveObjects = try allObjects(updatedSince: Persistence.Sync.BeamObjects.last_updated_at)

        guard !toSaveObjects.isEmpty else {
            completion(.success((0, nil)))
            return nil
        }
        let mostRecentUpdatedAt = toSaveObjects.compactMap({ $0.updatedAt }).sorted().last

        return try saveOnBeamObjectsAPI(toSaveObjects) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let savedObjects): completion(.success((savedObjects.count, mostRecentUpdatedAt)))
            }
        }
    }

    @discardableResult
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let beamObjectTypes = Set(objects.map { type(of: $0).beamObjectTypeName }).joined(separator: ", ")
        Logger.shared.logDebug("saveOnBeamObjectsAPI called with \(objects.count) objects of type \(beamObjectTypes) on API",
                               category: .beamObjectNetwork)

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        return try objectManager.saveToAPI(objects) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Could not save all \(objects.count) \(BeamObjectType.beamObjectTypeName) objects: \(error.localizedDescription)",
                                       category: .beamObjectNetwork)

                if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error {
                    self.manageInvalidChecksum(error, completion)
                    return
                }

                // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
                guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
                    completion(.failure(error))
                    return
                }

                self.manageMultipleErrors(objects, errors, completion)

            case .success(let remoteObjects):
                do {
                    if !remoteObjects.isEmpty {
                        try self.persistChecksum(remoteObjects)
                        self.checkPreviousChecksums(remoteObjects)
                    }

                    completion(.success(remoteObjects))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    @discardableResult
    func deleteFromBeamObjectAPI(_ id: UUID,
                                 _ completion: @escaping (Result<Bool, Error>) -> Void) throws -> APIRequest {
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

    func deleteFromBeamObjectAPI(_ ids: [UUID],
                                 _ completion: @escaping (Result<Bool, Error>) -> Void) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
        let objectManager = BeamObjectManager()

        for id in ids {
            group.enter()

            try objectManager.delete(id) { result in
                switch result {
                case .failure(let error):
                    lock.wait()
                    errors.append(error)
                    lock.signal()
                case .success: break
                }

                group.leave()
            }
        }

        group.wait()

        guard errors.isEmpty else {
            completion(.failure(BeamObjectManagerError.multipleErrors(errors)))
            return
        }

        completion(.success(true))
    }

    @discardableResult
    func deleteAllFromBeamObjectAPI(_ completion: @escaping (Result<Bool, Error>) -> Void) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        return try objectManager.deleteAll(BeamObjectType.beamObjectTypeName) { result in
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
                                  _ completion: @escaping ((Result<BeamObjectType?, Error>) -> Void)) throws -> APIRequest {
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
    func fetchAllFromBeamObjectAPI(_ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        return try objectManager.fetchAllObjects(completion)
    }

    @discardableResult
    func saveOnBeamObjectAPI(_ object: BeamObjectType,
                             _ completion: @escaping ((Result<BeamObjectType, Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

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
                            self.checkPreviousChecksums([newObject])

                            completion(.success(newObject))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            case .success(let remoteObject):
                do {
                    try self.persistChecksum([remoteObject])
                    self.checkPreviousChecksums([remoteObject])

                    completion(.success(remoteObject))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        return networkTask
    }

    internal func manageInvalidChecksum(_ error: Error,
                                        _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) {
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

            try self.saveOnBeamObjectsAPI(mergedObjects) { result in
                switch result {
                case .failure(let error):
                    if !goodObjects.isEmpty {
                        try? self.persistChecksum(goodObjects)
                        self.checkPreviousChecksums(goodObjects)
                    }
                    completion(.failure(error))
                case .success(let remoteObjects):
                    var allObjects: [BeamObjectType] = []
                    allObjects.append(contentsOf: goodObjects)
                    allObjects.append(contentsOf: remoteObjects)

                    do {
                        try self.saveObjectsAfterConflict(remoteObjects)
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
    internal func manageMultipleErrors(_ objects: [BeamObjectType],
                                       _ errors: [Error],
                                       _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) {

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
            try self.saveOnBeamObjectsAPI(newObjects) { result in
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
