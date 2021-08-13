import Foundation
import BeamCore

// swiftlint:disable file_length

/// How do you want to resolve checksum conflicts
enum BeamObjectConflictResolution {
    /// Overwrite remote object with values from local object
    case replace

    /// Raise invalidChecksum error, which will include remote object, sent object, and potentially other good objects if any
    case fetchRemoteAndError
}

class BeamObjectManager {
    static var managerInstances: [String: BeamObjectManagerDelegateProtocol] = [:]
    static var translators: [String: (BeamObjectManagerDelegateProtocol, [BeamObject]) -> Void] = [:]

    private static var networkRequests: [UUID: APIRequest] = [:]
    private static var networkRequestsWithoutID: [APIRequest] = []

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

    static func unregisterAll() {
        managerInstances = [:]
        translators = [:]
    }

    static func setup() {
        // Add any manager using BeamObjects here
        DocumentManager().registerOnBeamObjectManager()
        DatabaseManager().registerOnBeamObjectManager()
        PasswordManager().registerOnBeamObjectManager()
    }

    var conflictPolicyForSave: BeamObjectConflictResolution = .replace

    internal func parseObjects(_ beamObjects: [BeamObject]) -> Bool {
        let lastUpdatedAt = Persistence.Sync.BeamObjects.updated_at

        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        guard lastUpdatedAt == nil || !beamObjects.isEmpty else {
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
        var requests: [APIRequest] = []

        for (_, manager) in Self.managerInstances {
            group.enter()

            let localTimer = BeamDate.now
            Logger.shared.logDebug("saveAllToAPI using \(manager)",
                                   category: .beamObjectNetwork)
            do {
                let request = try manager.saveAllOnBeamObjectApi { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                        lock.wait()
                        errors.append(error)
                        lock.signal()
                    case .success: break
                    }

                    Logger.shared.logDebug("saveAllToAPI using \(manager) done",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)
                    group.leave()
                }

                if let request = request {
                    requests.append(request)
                    Self.networkRequestsWithoutID.append(request)
                }
            } catch {
                lock.wait()
                errors.append(error)
                lock.signal()
                group.leave()
            }
        }

        group.wait()

        guard errors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(errors)
        }
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
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

        try beamRequest.fetchAll(updatedAtAfter: lastUpdatedAt) { result in
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

        Self.networkRequestsWithoutID.append(beamRequest)
    }
}

// MARK: - Foundation BeamObjectProtocol
extension BeamObjectManager {
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()
        let beamObjects = try objects.map {
            try BeamObject($0, T.beamObjectTypeName)
        }

        try request.saveAll(beamObjects) { result in
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

        Self.networkRequestsWithoutID.append(request)
        return request
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                          _ error: Error,
                                                          _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) {

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            Logger.shared.logWarning("beamObjectInvalidChecksum -- could not save \(objects.count) objects",
                                     category: .beamObject)
            saveToAPIFailureBeamObjectInvalidChecksum(objects, error, completion)
            return
        case APIRequestError.apiErrors:
            Logger.shared.logWarning("APIRequestError.apiErrors -- could not save \(objects.count) objects",
                                     category: .beamObject)
            saveToAPIFailureApiErrors(objects, error, completion)
            return
        default:
            break
        }

        Logger.shared.logError("saveToAPIBeamObjectsFailure -- could not save \(objects.count) objects: \(error.localizedDescription)",
                               category: .beamObject)
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
            var fetchedObject: T?
            do {
                fetchedObject = try fetchObject(conflictedObject)
            } catch APIRequestError.notFound { }

            switch self.conflictPolicyForSave {
            case .replace:
                if let fetchedObject = fetchedObject {
                    conflictedObject = manageConflict(conflictedObject, fetchedObject)
                } else {
                    conflictedObject.previousChecksum = nil
                }

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
                                                                                    [fetchedObject].compactMap { $0 })))
            }
        } catch {
            completion(.failure(error))
        }
    }

    internal func fetchObjects<T: BeamObjectProtocol>(_ objects: [T]) throws -> [T] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Swift.Result<[T], Error>!

        try fetchObjects(objects) { fetchAllResult in
            result = fetchAllResult
            semaphore.signal()
        }

        let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
        if case .timedOut = semaphoreResult {
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object")
        }

        switch result {
        case .failure(let error): throw error
        case .success(let objects): return objects
        case .none:
            throw BeamObjectManagerDelegateError.runtimeError("Couldn't fetch object")
        }
    }

    /// Fetch remote objects
    @discardableResult
    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T],
                                             _ completion: @escaping (Result<[T], Error>) -> Void) throws -> APIRequest {
        try fetchBeamObjects(objects.map { $0.beamObjectId }) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObjects):
                var errors: [Error]?
                let remoteObjects: [T] = remoteBeamObjects.compactMap { remoteBeamObject in
                    // Check if you have the same IDs for 2 different object types
                    guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                        completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) \(remoteBeamObject.id) is not a \(T.beamObjectTypeName)")))
                        return nil
                    }

                    do {
                        let remoteObject: T = try remoteBeamObject.decodeBeamObject()
                        return remoteObject

                    } catch {
                        errors?.append(BeamObjectManagerError.decodingError(remoteBeamObject))
                    }

                    return nil
                }

                if let errors = errors {
                    completion(.failure(BeamObjectManagerError.multipleErrors(errors)))
                    return
                }

                completion(.success(remoteObjects))
            }
        }
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

                    let fetchedObject: T? = fetchedConflictedObjects.first(where: {
                        $0.beamObjectId == conflictedObject.beamObjectId
                    })

                    if let fetchedObject = fetchedObject {
                        return manageConflict(conflictedObject, fetchedObject)
                    } else {
                        var fixedConflictedObject: T = try conflictedObject.copy()
                        fixedConflictedObject.previousChecksum = nil
                        return fixedConflictedObject
                    }
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
                                          _ completion: @escaping ((Swift.Result<T, Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamObject = try BeamObject(object, T.beamObjectTypeName)

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        try request.save(beamObject) { requestResult in
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

        Self.networkRequestsWithoutID.append(request)
        return request
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

        Logger.shared.logWarning("Invalid Checksum. Local previousChecksum: \(object.previousChecksum ?? "-")",
                                 category: .beamObjectNetwork)

        do {
            var fetchedObject: T?
            do {
                fetchedObject = try fetchObject(object)
            } catch APIRequestError.notFound { }
            var conflictedObject: T = try object.copy()

            Logger.shared.logWarning("Remote object checksum: \(fetchedObject?.checksum ?? "-")",
                                   category: .beamObjectNetwork)

            switch self.conflictPolicyForSave {
            case .replace:
                if let fetchedObject = fetchedObject {
                    conflictedObject = manageConflict(conflictedObject, fetchedObject)
                } else {
                    conflictedObject.previousChecksum = nil
                }

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
                                                                                    [fetchedObject].compactMap { $0 })))
            }
        } catch {
            completion(.failure(error))
        }
    }

    /// Fetch remote object
    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T,
                                            _ completion: @escaping (Result<T, Error>) -> Void) throws -> APIRequest {
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
                                                     _ completion: @escaping (Result<Date?, Error>) -> Void) throws -> APIRequest {
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
                                                    _ completion: @escaping (Result<String?, Error>) -> Void) throws -> APIRequest {
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

    internal func manageConflict<T: BeamObjectProtocol>(_ object: T,
                                                        _ remoteObject: T) -> T {
        var result = object

        if remoteObject.updatedAt > object.updatedAt {
            result = remoteObject
        }

        result.previousChecksum = remoteObject.checksum
        return result
    }
}

// MARK: - Foundation BeamObject
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObject],
                   _ completion: @escaping ((Swift.Result<[BeamObject], Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.saveAll(beamObjects) { result in
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

        Self.networkRequestsWithoutID.append(request)
        return request
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
            do {
                try fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
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
            } catch {
                completion(.failure(error))
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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

            do {
                try fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
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
            } catch {
                lock.wait()
                resultErrors.append(error)
                lock.signal()
            }
        }

        group.wait()

        if conflictPolicyForSave == .fetchRemoteAndError, !newBeamObjects.isEmpty {
            fatalError("When using fetchRemoteAndError conflict policy, ")
        }

        if conflictPolicyForSave == .replace, !resultErrors.isEmpty {
            fatalError("When using replace conflict policy, ")
        }

        switch conflictPolicyForSave {
        case .replace:
            guard resultErrors.isEmpty else {
                fatalError("When using replace conflict policy, we won't raise error and therefore it should be empty")
            }
            do {
                _ = try saveToAPI(newBeamObjects, completion)
            } catch {
                completion(.failure(error))
            }
        case .fetchRemoteAndError:
            guard newBeamObjects.isEmpty else {
                fatalError("When using fetchRemoteAndError conflict policy, we will raise error and we shouldn't have already saved merged objects")
            }
            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
        }
    }

    func saveToAPI(_ beamObject: BeamObject,
                   _ completion: @escaping ((Swift.Result<BeamObject, Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[beamObject.id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[beamObject.id] = request

        try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success(let updateBeamObject):
                let savedBeamObject = updateBeamObject.copy()
                savedBeamObject.previousChecksum = updateBeamObject.dataChecksum
                completion(.success(savedBeamObject))
            case .failure(let error):
                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)",
                                           category: .beamObjectNetwork)
                    completion(.failure(error))
                    return
                }

                Logger.shared.logWarning("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                         category: .beamObjectNetwork)

                do {
                    try self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                        switch result {
                        case .failure: completion(result)
                        case .success(let newBeamObject):
                            do {
                                Logger.shared.logWarning("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                                         category: .beamObjectNetwork)
                                Logger.shared.logWarning("Overwriting local object with remote checksum",
                                                         category: .beamObjectNetwork)

                                _ = try self.saveToAPI(newBeamObject, completion)
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

        return request
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject,
                                                           _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws {
        try fetchBeamObject(beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                /*
                 We tried fetching the remote beam object but it doesn't exist, we set `previousChecksum` to `nil`
                 */
                if case APIRequestError.notFound = error {
                    let newBeamObject = beamObject.copy()
                    newBeamObject.previousChecksum = nil

                    switch self.conflictPolicyForSave {
                    case .replace:
                        completion(.success(newBeamObject))
                    case .fetchRemoteAndError:
                        completion(.failure(BeamObjectManagerError.invalidChecksum(newBeamObject)))
                    }
                }
                completion(.failure(error))
            case .success(let remoteBeamObject):
                // This happened during tests, but could happen again if you have the same IDs for 2 different objects
                guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
                    completion(.failure(BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)))
                    return
                }

                /*
                 We fetched the remote beam object, we set `previousChecksum` to the remote checksum
                 */

                switch self.conflictPolicyForSave {
                case .replace:
                    let newBeamObject = self.manageConflict(beamObject, remoteBeamObject)
                    completion(.success(newBeamObject))
                case .fetchRemoteAndError:
                    completion(.failure(BeamObjectManagerError.invalidChecksum(remoteBeamObject)))
                }
            }
        }
    }

    @discardableResult
    internal func fetchBeamObjects(_ beamObjects: [BeamObject],
                                   _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchAll(ids: beamObjects.map { $0.id }, completion)
        return request
    }

    @discardableResult
    internal func fetchBeamObjects(_ ids: [UUID],
                                   _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchAll(ids: ids, completion)
        return request
    }

    @discardableResult
    internal func fetchBeamObject(_ beamObject: BeamObject,
                                  _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetch(beamObject.id, completion)
        return request
    }

    @discardableResult
    internal func fetchBeamObject(_ id: UUID,
                                  _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetch(id, completion)
        return request
    }

    @discardableResult
    internal func fetchMinimalBeamObject(_ id: UUID,
                                         _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchMinimalBeamObject(id, completion)
        return request
    }

    @discardableResult
    func delete(_ id: UUID, _ completion: ((Swift.Result<BeamObject, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[id] = request

        try request.delete(id) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let object): completion?(.success(object))
            }
        }

        return request
    }

    @discardableResult
    func deleteAll(_ beamObjectType: String? = nil,
                   _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.deleteAll(beamObjectType: beamObjectType) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let success): completion?(.success(success))
            }
        }

        return request
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

// MARK: - For tests
extension BeamObjectManager {
    func clearNetworkCalls() {
        for (_, request) in Self.networkRequests {
            request.cancel()
        }

        for request in Self.networkRequestsWithoutID {
            request.cancel()
        }
    }

    /*
     Wrote this for our tests, and detect when we have still running network tasks on test ends. Sadly, this seems to
     not work when used with Vinyl, which doesn't implement `cancel()`.
     */
    func isAllNetworkCallsCompleted() -> Bool {
        for request in Self.networkRequestsWithoutID {
            if [URLSessionTask.State.suspended, .running].contains(request.dataTask?.state) {
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
}
