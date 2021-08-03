import Foundation
import BeamCore

// swiftlint:disable file_length

enum BeamObjectConflictResolution {
    // Will overwrite remote object with values from local ones
    case replace

    // Will fetch the remote object, and call the completion with an error and the remote object
    // so the caller can manage conflicts
    case fetchRemoteAndError
}

class BeamObjectManager {
    static var managerInstances: [String: BeamObjectManagerDelegateProtocol] = [:]
    static var translators: [String: (BeamObjectManagerDelegateProtocol, [BeamObject]) -> Void] = [:]

    private static var networkRequests: [UUID: APIRequest] = [:]
    private static var urlSessionTasks: [URLSessionTask] = []

    static func register<M: BeamObjectManagerDelegateProtocol, O: BeamObjectProtocol>(_ manager: M, object: O.Type) {
        managerInstances[object.beamObjectTypeName] = manager
        translators[object.beamObjectTypeName] = { manager, objects in
            do {
                let encapsulatedObjects: [O] = try objects.map {
                    try $0.decodeBeamObject()
                }

                try manager.parse(objects: encapsulatedObjects)
            } catch {
                Logger.shared.logError("manager \(manager) returned error: \(error.localizedDescription)",
                                       category: .beamObject)
            }
        }
    }

    static func unRegisterAll() {
        managerInstances = [:]
        translators = [:]
    }

    static func setup() {
        // Add any manager using BeamObjects here
        DocumentManager().registerOnBeamObjectManager()
        DatabaseManager().registerOnBeamObjectManager()
        PasswordManager().registerOnBeamObjectManager()
    }

    func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }

        for task in Self.urlSessionTasks {
            task.cancel()
        }
    }

    /*
     Wrote this for our tests, and detect when we have still running network tasks on test ends. Sadly, this seems to
     not work when used with Vinyl, which doesn't implement `cancel()`.
     */
    func isAllNetworkCallsCompleted() -> Bool {
        for task in Self.urlSessionTasks {
            if [URLSessionTask.State.suspended, .running].contains(task.state) {
                return false
            }
        }

        for (_, request) in Self.networkRequests {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
                return false
            }
        }

        return true
    }

    var conflictPolicyForSave: BeamObjectConflictResolution = .replace

    internal func parseObjects(_ beamObjects: [BeamObject]) -> Bool {
        let lastUpdatedAt = Persistence.Sync.BeamObjects.updated_at

        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        if lastUpdatedAt != nil && beamObjects.isEmpty {
            Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
            return true
        }

        if let mostRecentUpdatedAt = beamObjects.compactMap({ $0.updatedAt }).sorted().last {
            Logger.shared.logDebug("new updatedAt: \(mostRecentUpdatedAt). \(beamObjects.count) beam objects fetched.",
                                   category: .beamObjectNetwork)
        }

        let filteredObjects: [String: [BeamObject]] = beamObjects.reduce(into: [:]) { result, object in
            result[object.beamObjectType] = result[object.beamObjectType] ?? []
            result[object.beamObjectType]?.append(object)
        }

        parseFilteredObjects(filteredObjects)

//        dump(filteredObjects)

        return true
    }

    internal func parseFilteredObjects(_ filteredObjects: [String: [BeamObject]]) {
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

            translator(managerInstance, objects)
        }
    }

    internal func isErrorInvalidChecksum(_ error: UserErrorData) -> Bool {
        error.message == "Differs from current checksum" && error.path == ["attributes", "previous_checksum"]
    }
}

// MARK: - Foundation
extension BeamObjectManager {
    func syncAllFromAPI(delete: Bool = true, _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        try fetchAllFromAPI { result in
            switch result {
            case .failure:
                completion?(result)
            case .success(let success):
                guard success == true else {
                    completion?(result)
                    return
                }

                do {
                    try self.saveAllToAPI()
                    completion?(.success(true))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func saveAllToAPI() throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
        var dataTasks: [URLSessionTask] = []

        for (_, manager) in Self.managerInstances {
            group.enter()

            Logger.shared.logDebug("saveAllOnBeamObjectApi using \(manager)",
                                   category: .beamObjectNetwork)
            do {
                let task = try manager.saveAllOnBeamObjectApi { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                        lock.wait()
                        errors.append(error)
                        lock.signal()
                    case .success(let success):
                        guard success == true else {
                            lock.wait()
                            errors.append(BeamObjectManagerError.notSuccess)
                            lock.signal()
                            return
                        }
                    }

                    group.leave()
                }

                if let task = task {
                    dataTasks.append(task)
                    Self.urlSessionTasks.append(task)
                }
            } catch {
                lock.wait()
                errors.append(BeamObjectManagerError.notSuccess)
                lock.signal()
                group.leave()
            }
        }

        Logger.shared.logDebug("saveAllOnBeamObjectApi waiting",
                               category: .beamObjectNetwork)
        group.wait()

        Logger.shared.logDebug("saveAllOnBeamObjectApi waited",
                               category: .beamObjectNetwork)

        guard errors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(errors)
        }
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        // If not authenticated
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamRequest = BeamObjectRequest()

        let lastUpdatedAt: Date? = Persistence.Sync.BeamObjects.updated_at
        let timeNow = BeamDate.now

        if let lastUpdatedAt = lastUpdatedAt {
            Logger.shared.logDebug("Using updatedAt for BeamObjects API call: \(lastUpdatedAt)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        let task = try beamRequest.fetchAll(lastUpdatedAt) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logDebug("fetchAllFromAPI: \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                completion?(.failure(error))
            case .success(let beamObjects):
                let success = self.parseObjects(beamObjects)
                if success {
                    Persistence.Sync.BeamObjects.updated_at = timeNow
                }
                completion?(.success(success))
            }
        }

        Self.urlSessionTasks.append(task)
    }
}

// MARK: - Foundation BeamObjectProtocol
extension BeamObjectManager {
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()
        let beamObjects = try objects.map {
            try BeamObject($0, T.beamObjectTypeName)
        }

        let sessionTask = try request.saveAll(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIFailure(objects, error, completion)
            case .success(let remoteBeamObjects):
                // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
                // and set their `previousChecksum`
                // We'll use `copy()` when it's faster and doesn't encode/decode

                do {
                    // Caller will need to store those previousCheckum into its data storage, we must return it
                    let savedObjects: [T] = try beamObjects.map {
                        var remoteObject: T = try $0.decodeBeamObject()
                        remoteObject.previousChecksum = remoteBeamObjects.first(where: {
                            $0.id == remoteObject.beamObjectId
                        })?.dataChecksum

                        return remoteObject
                    }

                    completion(.success(savedObjects))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        guard let task = sessionTask else { return nil }

        Self.urlSessionTasks.append(task)
        return task
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                          _ error: Error,
                                                          _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) {
        Logger.shared.logError("saveToAPIBeamObjectsFailure -- could not save \(objects.count) objects: \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            saveToAPIFailureBeamObjectInvalidChecksum(objects, error, completion)
            return
        case APIRequestError.apiErrors:
            saveToAPIFailureApiErrors(objects, error, completion)
            return
        default:
            break
        }

        completion(.failure(error))
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

    internal func saveToAPIFailureBeamObjectInvalidChecksum<T: BeamObjectProtocol>(_ objects: [T],
                                                                                   _ error: Error,
                                                                                   _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) {
        guard case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects) = error,
              let remoteBeamObjects = (updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects else {
            completion(.failure(error))
            return
        }

        /*
         In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
         to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
         objects into `remoteObjects` to resend them back in the completion handler
         */

        // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
        guard var conflictedObject = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
            completion(.failure(error))
            return
        }

        var goodObjects: [T] = extractGoodObjects(objects, conflictedObject, remoteBeamObjects)

        do {
            let fetchedObject = try fetchObject(conflictedObject)

            switch self.conflictPolicyForSave {
            case .replace:
                conflictedObject.previousChecksum = fetchedObject.checksum

                _ = try self.saveToAPI(conflictedObject) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let newSavedObject):
                        conflictedObject.checksum = newSavedObject.checksum
                        conflictedObject.previousChecksum = newSavedObject.checksum
                        goodObjects.append(conflictedObject)

                        completion(.success(goodObjects))
                    }
                }
            case .fetchRemoteAndError:
                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                                    goodObjects,
                                                                                    [fetchedObject])))
            }
        } catch {
            completion(.failure(error))
        }
    }

    internal func fetchObjects<T: BeamObjectProtocol>(_ objects: [T]) throws -> [T] {
        let group = DispatchGroup()
        let groupSemaphore = DispatchSemaphore(value: 1)
        var groupErrors: [Error] = []
        var fetchedObjects: [T] = []

        for object in objects {
            group.enter()

            do {
                _ = try fetchObject(object) { result in
                    groupSemaphore.wait()
                    switch result {
                    case .failure(let error): groupErrors.append(error)
                    case .success(let fetchedObject): fetchedObjects.append(fetchedObject)
                    }
                    groupSemaphore.signal()
                    group.leave()
                }
            } catch {
                groupSemaphore.wait()
                groupErrors.append(error)
                groupSemaphore.signal()
                group.leave()

            }
        }

        group.wait()

        guard groupErrors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(groupErrors)
        }

        return fetchedObjects
    }

    internal func fetchObject<T: BeamObjectProtocol>(_ object: T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Swift.Result<T, Error>!

        try fetchObject(object) { fetchObjectResult in
            result = fetchObjectResult
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
        if case .timedOut = semaphoreResult {
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object")
        }

        switch result {
        case .failure(let error): throw error
        case .success(let object): return object
        case .none:
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object")
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

    // swiftlint:disable:next function_body_length
    internal func saveToAPIFailureApiErrors<T: BeamObjectProtocol>(_ objects: [T],
                                                                   _ error: Error,
                                                                   _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) {
        guard case APIRequestError.apiErrors(let errorable) = error,
              let remoteBeamObjects = (errorable as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects,
              let errors = errorable.errors else {
            completion(.failure(error))
            return
        }

        /*
         Note: we might have multiple error types on return, like 1 checksum issue and 1 unrelated issue. We should
         only get conflicted objects

         TODO: if we have another error type, we should probably call completion with that error instead. Question is
         do we still proceed the checksum errors or not.
         */

        let objectErrorIds: [String] = errors.compactMap {
            guard isErrorInvalidChecksum($0) else { return nil }

            return $0.objectid?.lowercased()
        }

        let conflictedObjects: [T] = objects.filter {
            objectErrorIds.contains($0.beamObjectId.uuidString.lowercased())
        }

        var goodObjects: [T] = extractGoodObjects(objects, objectErrorIds, remoteBeamObjects)

        do {
            let fetchedConflictedObjects = try fetchObjects(conflictedObjects)

            switch self.conflictPolicyForSave {
            case .replace:
                let toSaveObjects: [T] = try conflictedObjects.compactMap {
                    let conflictedObject = $0

                    guard let fetchedObject: T = fetchedConflictedObjects.first(where: {
                        $0.beamObjectId == conflictedObject.beamObjectId
                    }) else {
                        return nil
                    }
                    var fixedConflictedObject: T = try conflictedObject.copy()
                    fixedConflictedObject.previousChecksum = fetchedObject.checksum

                    return fixedConflictedObject
                }

                _ = try saveToAPI(toSaveObjects) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let savedObjects):
                        let toSaveObjectsWithChecksum: [T] = toSaveObjects.map {
                            var toSaveObject = $0
                            let savedObject = savedObjects.first(where: { $0.beamObjectId == toSaveObject.beamObjectId })
                            toSaveObject.previousChecksum = savedObject?.checksum
                            return toSaveObject
                        }

                        goodObjects.append(contentsOf: toSaveObjectsWithChecksum)
                        completion(.success(goodObjects))
                    }
                }
            case .fetchRemoteAndError:
                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum(conflictedObjects,
                                                                                    goodObjects,
                                                                                    fetchedConflictedObjects)))
            }
        } catch {
            completion(.failure(error))
            return
        }
    }

    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          _ completion: @escaping ((Swift.Result<T, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamObject = try BeamObject(object, T.beamObjectTypeName)

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        let sessionTask = try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success(let remoteBeamObject):
                // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
                // and set their `previousChecksum`

                // We'll use `copy()` when it's faster and doesn't encode/decode

                do {
                    var savedObject: T = try beamObject.decodeBeamObject()
                    savedObject.previousChecksum = remoteBeamObject.dataChecksum

                    completion(.success(savedObject))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                self.saveToAPIFailure(object, error, completion)
            }
        }

        Self.urlSessionTasks.append(sessionTask)
        return sessionTask
    }

    func saveToAPIFailure<T: BeamObjectProtocol>(_ object: T,
                                                 _ error: Error,
                                                 _ completion: @escaping ((Swift.Result<T, Error>) -> Void)) {
        Logger.shared.logError("Could not save \(object): \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        // Early return except for checksum issues.
        guard case APIRequestError.beamObjectInvalidChecksum = error else {
            completion(.failure(error))
            return
        }

        Logger.shared.logError("Invalid Checksum. Local previous checksum: \(object.previousChecksum ?? "-")",
                               category: .beamObjectNetwork)

        do {
            let fetchedObject = try fetchObject(object)
            var conflictedObject: T = try object.copy()

            Logger.shared.logWarning("Remote object checksum: \(fetchedObject.checksum ?? "-")",
                                   category: .beamObjectNetwork)

            switch self.conflictPolicyForSave {
            case .replace:
                conflictedObject.previousChecksum = fetchedObject.checksum

                _ = try self.saveToAPI(conflictedObject) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let newSavedObject):
                        conflictedObject.previousChecksum = newSavedObject.checksum

                        completion(.success(conflictedObject))
                    }
                }
            case .fetchRemoteAndError:
                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                                    [],
                                                                                    [fetchedObject])))
            }
        } catch {
            completion(.failure(error))
        }
    }

    /// Fetch remote object
    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T,
                                            _ completion: @escaping (Result<T, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchBeamObject(object.beamObjectId) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")))
                    return
                }

                do {
                    let remoteObject: T = try remoteBeamObject.decodeBeamObject()
                    completion(.success(remoteObject))
                } catch {
                    completion(.failure(BeamObjectManagerError.decodingError(remoteBeamObject)))
                }
            }
        }
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(_ object: T,
                                                     _ completion: @escaping (Result<Date?, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchMinimalBeamObject(object.beamObjectId) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")))
                    return
                }

                completion(.success(remoteBeamObject.updatedAt))
            }
        }
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(_ object: T,
                                                    _ completion: @escaping (Result<String?, Error>) -> Void) throws -> URLSessionDataTask {
        try fetchMinimalBeamObject(object.beamObjectId) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")))
                    return
                }

                completion(.success(remoteBeamObject.dataChecksum))
            }
        }
    }
}

// MARK: - Foundation BeamObject
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObject],
                   _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        let sessionTask = try request.saveAll(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIBeamObjectsFailure(beamObjects, error, completion)
            case .success(let updateBeamObjects):
                let savedBeamObjects: [BeamObject] = updateBeamObjects.map {
                    let result = $0.copy()
                    result.previousChecksum = $0.dataChecksum
                    return result
                }

                completion(.success(savedBeamObjects))
            }
        }

        guard let task = sessionTask else { return nil }

        Self.urlSessionTasks.append(task)
        return task
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              _ error: Error,
                                              _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) {
        Logger.shared.logError("Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects):
            /*
             In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
             to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
             objects into `remoteObjects` to resend them back in the completion handler
             */

            guard let updateBeamObjects = updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects,
                  let remoteBeamObjects = updateBeamObjects.beamObjects else {
                completion(.failure(error))
                return
            }

            // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                completion(.failure(error))
                return
            }

            // Set `checksum` on the objects who were saved successfully as this will be used later
            var remoteFilteredBeamObjects: [BeamObject] = beamObjects.compactMap {
                if beamObject.id == $0.id { return nil }

                let remoteObject = $0
                remoteObject.dataChecksum = remoteBeamObjects.first(where: {
                    $0.id == remoteObject.id
                })?.dataChecksum

                return remoteObject
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let beamObject):
                    do {
                        _ = try self.saveToAPI(beamObject) { result in
                            switch result {
                            case .failure(let error): completion(.failure(error))
                            case .success(let remoteFilteredBeamObject):
                                remoteFilteredBeamObjects.append(remoteFilteredBeamObject)
                                completion(.success(remoteFilteredBeamObjects))
                            }
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            return
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            saveToAPIFailureAPIErrors(beamObjects, errors, completion)
            return
        default:
            break
        }

        completion(.failure(error))
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObject],
                                            _ errors: [UserErrorData],
                                            _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) {
        // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
        // the error we'll return to the object calling this manager
        let group = DispatchGroup()

        var resultErrors: [Error] = []
        var newBeamObjects: [BeamObject] = []
        let lock = DispatchSemaphore(value: 1)

        for error in errors {
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                continue
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard isErrorInvalidChecksum(error) else { continue }

            group.enter()

            fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                switch result {
                case .failure(let error):
                    lock.wait()
                    resultErrors.append(error)
                    lock.signal()
                case .success(let beamObject):
                    lock.wait()
                    newBeamObjects.append(beamObject)
                    lock.signal()
                }
                group.leave()
            }
        }

        group.wait()

        if !newBeamObjects.isEmpty, conflictPolicyForSave == .fetchRemoteAndError {
            fatalError("Should never happen")
        }

        if !resultErrors.isEmpty, conflictPolicyForSave == .replace {
            fatalError("Should never happen")
        }

        switch conflictPolicyForSave {
        case .replace:
            guard resultErrors.isEmpty else {
                fatalError("Should never happen")
            }
            do {
                _ = try saveToAPI(newBeamObjects, completion)
            } catch {
                completion(.failure(error))
            }
        case .fetchRemoteAndError:
            guard newBeamObjects.isEmpty else {
                fatalError("Should never happen")
            }
            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
        }
    }

    func saveToAPI(_ beamObject: BeamObject,
                   _ completion: @escaping ((Swift.Result<BeamObject, Error>) -> Void)) throws -> URLSessionTask? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        let sessionTask = try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success(let updateBeamObject):
                let savedBeamObject = updateBeamObject.copy()
                savedBeamObject.previousChecksum = updateBeamObject.dataChecksum
                completion(.success(savedBeamObject))
            case .failure(let error):
                Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)",
                                       category: .beamObjectNetwork)

                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    completion(.failure(error))
                    return
                }

                Logger.shared.logError("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                       category: .beamObjectNetwork)

                self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                    switch result {
                    case .failure: completion(result)
                    case .success(let newBeamObject):
                        do {
                            Logger.shared.logError("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                                   category: .beamObjectNetwork)
                            Logger.shared.logError("Overwriting local object with remote checksum",
                                                   category: .beamObjectNetwork)

                            _ = try self.saveToAPI(newBeamObject, completion)
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }

        Self.urlSessionTasks.append(sessionTask)
        return sessionTask
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject,
                                                           _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        fetchBeamObject(beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // This happened during tests, but could happen again if you have the same IDs for 2 different objects
                guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
                    completion(.failure(BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)))
                    return
                }

                switch self.conflictPolicyForSave {
                case .replace:
                    let newBeamObject = beamObject.copy()
                    newBeamObject.previousChecksum = remoteBeamObject.dataChecksum
                    completion(.success(newBeamObject))
                case .fetchRemoteAndError:
                    completion(.failure(BeamObjectManagerError.invalidChecksum(remoteBeamObject)))
                }
            }
        }
    }

    internal func fetchBeamObject(_ beamObject: BeamObject,
                                  _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(beamObject.id, completion)
        } catch {
            completion(.failure(error))
        }
    }

    @discardableResult
    internal func fetchBeamObject(_ id: UUID,
                                  _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try BeamObjectRequest().fetch(id, completion)
    }

    @discardableResult
    internal func fetchMinimalBeamObject(_ id: UUID,
                                         _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> URLSessionDataTask {
        try BeamObjectRequest().fetchMinimalBeamObject(id, completion)
    }

    @discardableResult
    func delete(_ id: UUID, _ completion: ((Swift.Result<BeamObject, Error>) -> Void)? = nil) throws -> URLSessionDataTask {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[id] = request

        return try request.delete(id) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let object): completion?(.success(object))
            }
        }
    }
}

// swiftlint:enable file_length
