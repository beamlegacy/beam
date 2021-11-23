import Foundation
import BeamCore
// swiftlint:disable file_length

extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi(_ completion: @escaping ((Result<(Int, Date?), Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        self.willSaveAllOnBeamObjectApi()

        let localTimer = BeamDate.now

        let toSaveObjects = try allObjects(updatedSince: Persistence.Sync.BeamObjects.last_updated_at)

        Logger.shared.logDebug("\(Self.BeamObjectType.beamObjectTypeName) manager returned \(toSaveObjects.count) objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

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
    // swiftlint:disable:next function_body_length
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              force: Bool = false,
                              deep: Int = 0,
                              refreshPreviousChecksum: Bool = true,
                              _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        guard deep < 3 else {
            completion(.failure(BeamObjectManagerDelegateError.nestedTooDeep))
            return nil
        }

        if Thread.isMainThread, Configuration.env != "test" {
            Logger.shared.logError("Please don't use saveOnBeamObjectsAPI in the main thread. Create your own DispatchQueue instead.",
                                   category: .beamObjectNetwork)
            assert(false)
        }

        let beamObjectTypes = Set(objects.map { type(of: $0).beamObjectTypeName }).joined(separator: ", ")
        Logger.shared.logDebug("saveOnBeamObjectsAPI called with \(objects.count) objects of type \(beamObjectTypes)",
                               category: .beamObjectNetwork)

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        let uuids = objects.map { $0.beamObjectId }
        let semaphores = BeamObjectManagerCall.objectsSemaphores(uuids: uuids)
        semaphores.forEach {
            let semaResult = $0.wait(timeout: DispatchTime.now() + .seconds(10))

            if case .timedOut = semaResult {
                Logger.shared.logError("network semaphore expired", category: .beamObjectNetwork)
            }
        }

        // A previous network call might have changed the previousChecksum in the meantime
        let checksums = try checksumsForIds(objects.map { $0.beamObjectId })

        let objectsToSave: [BeamObjectType] = try objects.map {
            var objectToSave = try $0.copy()
            if refreshPreviousChecksum {
                objectToSave.previousChecksum = checksums[$0.beamObjectId]
            }
            return objectToSave
        }

        var networkTask: APIRequest?

        do {
            networkTask = try objectManager.saveToAPI(objectsToSave) { result in
                switch result {
                case .failure(let error):
                    self.saveOnBeamObjectsAPIError(objects: objectsToSave,
                                                   uuids: uuids,
                                                   semaphores: semaphores,
                                                   deep: deep,
                                                   error: error,
                                                   completion)

                case .success(let remoteObjects):
                    self.saveOnBeamObjectsAPISuccess(uuids: uuids,
                                                     remoteObjects: remoteObjects,
                                                     semaphores: semaphores,
                                                     completion)
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
            BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
            semaphores.forEach { $0.signal() }
        }

        return networkTask
    }

    internal func saveOnBeamObjectsAPISuccess(uuids: [UUID],
                                              remoteObjects: [BeamObjectType],
                                              semaphores: [DispatchSemaphore],
                                              _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) {
        do {
            if !remoteObjects.isEmpty {
                try self.persistChecksum(remoteObjects)
                self.checkPreviousChecksums(remoteObjects)
            }

            completion(.success(remoteObjects))
        } catch {
            completion(.failure(error))
        }

        BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
        semaphores.forEach { $0.signal() }
    }

    internal func saveOnBeamObjectsAPIError(objects: [BeamObjectType],
                                            uuids: [UUID],
                                            semaphores: [DispatchSemaphore],
                                            deep: Int,
                                            error: Error,
                                            _ completion: @escaping ((Result<[BeamObjectType], Error>) -> Void)) {
        Logger.shared.logError("Could not save all \(objects.count) \(BeamObjectType.beamObjectTypeName) objects: \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error {
            BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
            semaphores.forEach { $0.signal() }

            self.manageInvalidChecksum(error, deep, completion)
            return
        }

        // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
        guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
            BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
            semaphores.forEach { $0.signal() }

            completion(.failure(error))
            return
        }

        self.manageMultipleErrors(objects, errors, completion)

        BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
        semaphores.forEach { $0.signal() }
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
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func refreshFromBeamObjectAPI(_ object: BeamObjectType,
                                  _ forced: Bool = false,
                                  _ completion: @escaping ((Result<BeamObjectType?, Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        let semaphore = BeamObjectManagerCall.objectSemaphore(uuid: object.beamObjectId)
        semaphore.wait()

        guard !forced else {
            return try objectManager.fetchObject(object) { result in
                switch result {
                case .failure(let error):
                    if case APIRequestError.notFound = error {
                        completion(.success(nil))
                        BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                        semaphore.signal()
                        return
                    }
                    completion(.failure(error))
                case .success(let remoteObject): completion(.success(remoteObject))
                }

                BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                semaphore.signal()
            }
        }

        return try objectManager.fetchObjectUpdatedAt(object) { result in
            switch result {
            case .failure(let error):
                if case APIRequestError.notFound = error {
                    completion(.success(nil))
                    BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                    semaphore.signal()
                    return
                }

                completion(.failure(error))
            case .success(let updatedAt):
                guard let updatedAt = updatedAt, updatedAt > object.updatedAt else {
                    completion(.success(nil))
                    BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                    semaphore.signal()
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

            BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
            semaphore.signal()
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
                             force: Bool = false,
                             _ completion: @escaping ((Result<BeamObjectType, Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        if Thread.isMainThread, Configuration.env != "test" {
            Logger.shared.logError("Please don't use saveOnBeamObjectAPI in the main thread. Create your own DispatchQueue instead.",
                                   category: .beamObjectNetwork)
            assert(false)
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        Logger.shared.logDebug("saveOnBeamObjectAPI called. Object \(object.beamObjectId), type: \(type(of: object).beamObjectTypeName)",
                               category: .beamObjectNetwork)

        let semaphore = BeamObjectManagerCall.objectSemaphore(uuid: object.beamObjectId)
        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))

        if case .timedOut = semaResult {
            Logger.shared.logError("network semaphore expired for Object \(object.beamObjectId), type: \(type(of: object).beamObjectTypeName)",
                                   category: .beamObjectNetwork)
        }

        var objectToSave = try object.copy()

        // A previous network call might have changed the previousChecksum in the meantime
        objectToSave.previousChecksum = (try checksumsForIds([object.beamObjectId]))[object.beamObjectId]

        var networkTask: APIRequest?

        do {
            networkTask = try objectManager.saveToAPI(objectToSave) { result in
                switch result {
                case .failure(let error):
                    self.saveOnBeamObjectAPIError(object: object,
                                                  semaphore: semaphore,
                                                  error: error,
                                                  completion)
                case .success(let remoteObject):
                    self.saveOnBeamObjectAPISuccess(object: object,
                                                    remoteObject: remoteObject,
                                                    semaphore: semaphore,
                                                    completion)
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
            BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
            semaphore.signal()
        }

        return networkTask
    }

    internal func saveOnBeamObjectAPISuccess(object: BeamObjectType,
                                             remoteObject: BeamObjectType,
                                             semaphore: DispatchSemaphore,
                                             _ completion: @escaping ((Result<BeamObjectType, Error>) -> Void)) {
        do {
            try self.persistChecksum([remoteObject])
            self.checkPreviousChecksums([remoteObject])

            completion(.success(remoteObject))
        } catch {
            completion(.failure(error))
        }

        BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
        semaphore.signal()
    }

    internal func saveOnBeamObjectAPIError(object: BeamObjectType,
                                           semaphore: DispatchSemaphore,
                                           error: Error,
                                           _ completion: @escaping ((Result<BeamObjectType, Error>) -> Void)) {
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error else {
            completion(.failure(error))

            BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
            semaphore.signal()

            return
        }

        // When dealing with invalid checksum, we will retry the `saveOnBeamObjectAPI` so semaphore must be unlocked
        // first
        BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
        semaphore.signal()

        self.manageInvalidChecksum(error, 0) { result in
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
    }

    internal func manageInvalidChecksum(_ error: Error,
                                        _ deep: Int,
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

            try self.saveOnBeamObjectsAPI(mergedObjects, deep: deep + 1, refreshPreviousChecksum: false) { result in
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
