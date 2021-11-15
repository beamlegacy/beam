import Foundation
import BeamCore

// swiftlint:disable file_length

extension BeamObjectManager {
    func syncAllFromAPI(delete: Bool = true, _ completion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        var localTimer = BeamDate.now

        try fetchAllByChecksumsFromAPI { result in
            switch result {
            case .failure:
                completion?(result)
            case .success:
                Logger.shared.logDebug("Calling saveAllToAPI, called FetchAllFromAPI",
                                       category: .beamObjectNetwork,
                                       localTimer: localTimer)

                do {
                    localTimer = BeamDate.now
                    let objectsCount = try self.saveAllToAPI()
                    Logger.shared.logDebug("Called saveAllToAPI, saved \(objectsCount) objects",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)

                    completion?(.success(true))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    func saveAllToAPI() throws -> Int {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
        var savedObjects = 0
        // Just a very old date as default
        var mostRecentUpdatedAt: Date = Persistence.Sync.BeamObjects.last_updated_at ?? (BeamDate.now.addingTimeInterval(-(60*60*24*31*12*10)))
        var mostRecentUpdatedAtChanged = false

        if let updatedAt = Persistence.Sync.BeamObjects.last_updated_at {
            Logger.shared.logDebug("Using updatedAt for BeamObjects API call: \(updatedAt)", category: .beamObjectNetwork)
        }

        for (_, manager) in Self.managerInstances {
            group.enter()

            DispatchQueue.global(qos: .userInitiated).async {
                let localTimer = BeamDate.now

                do {
                    let request = try manager.saveAllOnBeamObjectApi { result in
                        switch result {
                        case .failure(let error):
                            Logger.shared.logError("Can't saveAll: \(error.localizedDescription)", category: .beamObjectNetwork)
                            lock.wait()
                            errors.append(error)
                            lock.signal()
                        case .success(let countAndDate):
                            lock.wait()

                            savedObjects += countAndDate.0

                            if let updatedAt = countAndDate.1, updatedAt > mostRecentUpdatedAt {
                                mostRecentUpdatedAt = updatedAt
                                mostRecentUpdatedAtChanged = true
                            }

                            lock.signal()
                        }

                        Logger.shared.logDebug("saveAllToAPI using \(manager) done",
                                               category: .beamObjectNetwork,
                                               localTimer: localTimer)
                        group.leave()
                    }

                    if let request = request {
                        #if DEBUG
                        Self.networkRequestsWithoutID.append(request)
                        #endif
                    }
                } catch {
                    lock.wait()
                    errors.append(error)
                    lock.signal()
                    group.leave()
                }
            }
        }

        group.wait()

        guard errors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(errors)
        }

        if mostRecentUpdatedAtChanged {
            Logger.shared.logDebug("Updating last_updated_at from \(String(describing: Persistence.Sync.BeamObjects.last_updated_at)) to \(mostRecentUpdatedAt)",
                                   category: .beamObjectNetwork)
            Persistence.Sync.BeamObjects.last_updated_at = mostRecentUpdatedAt
        }

        return savedObjects
    }

    // Will fetch remote checksums for objects since `lastReceivedAt` and then fetch objects for which we have a different
    // checksum locally, and therefor must be fetched from the API. This allows for a faster fetch since most of the time
    // we might already have those object locally if they had been sent and updated from the same device
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func fetchAllByChecksumsFromAPI(_ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        try beamRequest.fetchAllChecksums(receivedAtAfter: lastReceivedAt) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                completion(.failure(error))
            case .success(let beamObjects):
                // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
                // If not doing a delta sync, we don't as we want to update local document as `deleted`
                guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                    Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
                    completion(.success(true))
                    return
                }

                do {
                    let changedObjects = try self.parseFilteredObjectChecksums(self.filteredObjects(beamObjects))

                    let ids: [UUID] = changedObjects.values.flatMap { $0.map { $0.id }}

                    guard !ids.isEmpty else {
                        if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
                            Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                            Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) beam object checksums fetched.",
                                                   category: .beamObjectNetwork)
                        }
                        completion(.success(true))
                        return
                    }

                    Logger.shared.logDebug("Need to fetch \(ids.count) objects remotely, different previousChecksum",
                                           category: .beamObjectNetwork)
                    let beamRequestForIds = BeamObjectRequest()

                    try beamRequestForIds.fetchAll(receivedAtAfter: nil, ids: ids) { result in
                        switch result {
                        case .failure(let error):
                            Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(error.localizedDescription)",
                                                   category: .beamObjectNetwork)
                            completion(.failure(error))
                        case .success(let beamObjects):
                            // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
                            // If not doing a delta sync, we don't as we want to update local document as `deleted`
                            guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                                Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
                                completion(.success(true))
                                return
                            }

                            if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
                                Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                                Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) beam objects fetched.",
                                                       category: .beamObjectNetwork)
                            }

                            do {
                                try self.parseFilteredObjects(self.filteredObjects(beamObjects))
                                completion(.success(true))
                                return
                            } catch {
                                AppDelegate.showMessage("Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support.")
                                completion(.failure(error))
                            }
                        }
                    }

                    #if DEBUG
                    Self.networkRequestsWithoutID.append(beamRequestForIds)
                    #endif
                } catch {
                    AppDelegate.showMessage("Error fetching objects from API then storing locally: \(error.localizedDescription). This is not normal, check the logs and ask support.")
                    completion(.failure(error))
                }
            }
        }

        #if DEBUG
        Self.networkRequestsWithoutID.append(beamRequest)
        #endif
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI(_ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        try beamRequest.fetchAll(receivedAtAfter: lastReceivedAt) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logDebug("fetchAllFromAPI: \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                completion(.failure(error))
            case .success(let beamObjects):
                // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
                // If not doing a delta sync, we don't as we want to update local document as `deleted`
                guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                    Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
                    completion(.success(true))
                    return
                }

                if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
                    Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                    Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) beam objects fetched.",
                                           category: .beamObjectNetwork)
                }

                do {
                    try self.parseFilteredObjects(self.filteredObjects(beamObjects))
                    completion(.success(true))
                    return
                } catch {
                    AppDelegate.showMessage("Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support.")
                    completion(.failure(error))
                }
            }
        }

        #if DEBUG
        Self.networkRequestsWithoutID.append(beamRequest)
        #endif
    }
}

// MARK: - BeamObjectProtocol
extension BeamObjectManager {
    func updatedObjectsOnly(_ objects: [BeamObject]) -> [BeamObject] {
        objects.filter {
            $0.previousChecksum != $0.dataChecksum || $0.previousChecksum == nil
        }
    }

    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          _ completion: @escaping ((Result<[T], Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()
        let beamObjects = try objects.map {
            try BeamObject($0, T.beamObjectTypeName)
        }

        let objectsToSave = Persistence.Sync.BeamObjects.last_updated_at == nil ? beamObjects : updatedObjectsOnly(beamObjects)

        guard !objectsToSave.isEmpty else {
            Logger.shared.logDebug("Not saving objects on API, list is empty after checksum check",
                                   category: .beamObjectNetwork)
            completion(.success([]))
            return nil
        }

        let beamObjectTypes = Set(objectsToSave.map { $0.beamObjectType }).joined(separator: ", ")
        Logger.shared.logDebug("Saving \(objectsToSave.count) objects of type \(beamObjectTypes) on API",
                               category: .beamObjectNetwork)
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

        #if DEBUG
        Self.networkRequestsWithoutID.append(request)
        #endif
        return request
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                          _ error: Error,
                                                          _ completion: @escaping ((Result<[T], Error>) -> Void)) {

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            Logger.shared.logWarning("beamObjectInvalidChecksum -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                     category: .beamObject)
            saveToAPIFailureBeamObjectInvalidChecksum(objects, error, completion)
            return
        case APIRequestError.apiErrors:
            Logger.shared.logWarning("APIRequestError.apiErrors -- could not save \(objects.count) objects: \(error.localizedDescription)",
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

    internal func saveToAPIFailureBeamObjectInvalidChecksum<T: BeamObjectProtocol>(_ objects: [T],
                                                                                   _ error: Error,
                                                                                   _ completion: @escaping ((Result<[T], Error>) -> Void)) {
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

    /// Fetch remote objects
    @discardableResult
    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T],
                                             _ completion: @escaping (Result<[T], Error>) -> Void) throws -> APIRequest {
        try fetchBeamObjects(objects.map { $0.beamObjectId }) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObjects):
                do {
                    completion(.success(try self.beamObjectsToObjects(remoteBeamObjects)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Fetch all remote objects
    @discardableResult
    func fetchAllObjects<T: BeamObjectProtocol>(_ completion: @escaping (Result<[T], Error>) -> Void) throws -> APIRequest {
        try fetchBeamObjects(T.beamObjectTypeName) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObjects):
                do {
                    completion(.success(try self.beamObjectsToObjects(remoteBeamObjects)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func saveToAPIFailureApiErrors<T: BeamObjectProtocol>(_ objects: [T],
                                                                   _ error: Error,
                                                                   _ completion: @escaping ((Result<[T], Error>) -> Void)) {
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
            guard $0.isErrorInvalidChecksum else { return nil }

            return $0.objectid?.lowercased()
        }

        let conflictedObjects: [T] = objects.filter {
            objectErrorIds.contains($0.beamObjectId.uuidString.lowercased())
        }

        var goodObjects: [T] = extractGoodObjects(objects, objectErrorIds, remoteBeamObjects)

        do {
            try fetchObjects(conflictedObjects) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let fetchedConflictedObjects):
                    switch self.conflictPolicyForSave {
                    case .replace:

                        // When we fetch objects but they have a different encryption key,
                        // fetchedConflictedObjects will be empty and we don't know what to do with it since we can't
                        // decode them or view their paste checksum for now
                        // TODO: fetch remote object checksums and overwrite
                        guard fetchedConflictedObjects.count == conflictedObjects.count else {
                            completion(.failure(BeamObjectManagerError.fetchError))
                            return
                        }

                        do {
                            let toSaveObjects: [T] = try conflictedObjects.compactMap {
                                let conflictedObject = $0

                                let fetchedObject: T? = fetchedConflictedObjects.first(where: {
                                    $0.beamObjectId == conflictedObject.beamObjectId
                                })

                                if let fetchedObject = fetchedObject {
                                    return self.manageConflict(conflictedObject, fetchedObject)
                                } else {
                                    var fixedConflictedObject: T = try conflictedObject.copy()
                                    fixedConflictedObject.previousChecksum = nil
                                    return fixedConflictedObject
                                }
                            }

                            _ = try self.saveToAPI(toSaveObjects) { result in
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
                        } catch {
                            completion(.failure(error))
                        }
                    case .fetchRemoteAndError:
                        completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum(conflictedObjects,
                                                                                            goodObjects,
                                                                                            fetchedConflictedObjects)))
                    }
                }
            }
        } catch {
            completion(.failure(error))
            return
        }
    }

    /// Completion will not be called if returned `APIRequest` is `nil`
    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          _ completion: @escaping ((Result<T, Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamObject = try BeamObject(object, T.beamObjectTypeName)

        let request = BeamObjectRequest()

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

        #if DEBUG
        Self.networkRequestsWithoutID.append(request)
        #endif

        return request
    }

    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ object: T,
                                                          _ error: Error,
                                                          _ completion: @escaping ((Result<T, Error>) -> Void)) {
        Logger.shared.logError("saveToAPIFailure: Could not save \(object): \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        // Early return except for checksum issues.
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
}

// MARK: - BeamObject
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObject],
                   _ completion: @escaping ((Result<[BeamObject], Error>) -> Void)) throws -> APIRequest {
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

        #if DEBUG
        Self.networkRequestsWithoutID.append(request)
        #endif

        return request
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              _ error: Error,
                                              _ completion: @escaping ((Result<[BeamObject], Error>) -> Void)) {
        Logger.shared.logError("saveToAPIBeamObjectsFailure: Could not save \(beamObjects): \(error.localizedDescription)",
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
                                            _ completion: @escaping ((Result<[BeamObject], Error>) -> Void)) {
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
            guard error.isErrorInvalidChecksum else { continue }

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
                   _ completion: @escaping ((Result<BeamObject, Error>) -> Void)) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success(let updateBeamObject):
                let savedBeamObject = updateBeamObject.copy()
                savedBeamObject.previousChecksum = updateBeamObject.dataChecksum
                completion(.success(savedBeamObject))
            case .failure(let error):
                // Early return except for checksum issues.
                guard case APIRequestError.beamObjectInvalidChecksum = error else {
                    Logger.shared.logError("saveToAPI Could not save \(beamObject): \(error.localizedDescription)",
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
    internal func fetchBeamObjectChecksums(_ ids: [UUID],
                                           _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchAll(ids: ids, completion)
        return request
    }

    @discardableResult
    internal func fetchBeamObjects(_ beamObjectType: String,
                                   _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchAll(beamObjectType: beamObjectType, completion)
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
    func delete(_ id: UUID, raise404: Bool = false, _ completion: ((Result<BeamObject?, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.delete(id) { result in
            switch result {
            case .failure(let error):
                // We don't mind 404
                if raise404 || !BeamError.isNotFound(error) {
                    completion?(.failure(error))
                } else {
                    completion?(.success(nil))
                }
            case .success(let object): completion?(.success(object))
            }
        }

        return request
    }

    @discardableResult
    func deleteAll(_ beamObjectType: String? = nil,
                   _ completion: ((Result<Bool, Error>) -> Void)? = nil) throws -> APIRequest {
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
}
