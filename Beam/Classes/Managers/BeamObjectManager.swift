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
}

// MARK: - Foundation
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
                self.saveToAPIBeamObjectsFailure(objects, error, completion)
            case .success(let remoteBeamObjects):
                // Not: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving.

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
    internal func saveToAPIBeamObjectsFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                                     _ error: Error,
                                                                     _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) {
        Logger.shared.logError("saveToAPIBeamObjectsFailure -- could not save \(objects.count) objects: \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects):
            Logger.shared.logDebug("⚠️ saveToAPIBeamObjectsFailure: APIRequestError.beamObjectInvalidChecksum",
                                   category: .beamObject)

            Logger.shared.logDebug("⚠️ updateBeamObjects", category: .beamObjectNetwork)
            dump(updateBeamObjects)

            /*
             In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
             to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
             objects into `remoteObjects` to resend them back in the completion handler
             */

            // Make sure we have proper network request call, including the objects which were properly saved
            guard let remoteBeamObjects = (updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects else {
                completion(.failure(error))
                return
            }

            // Note: `remoteBeamObjects` are BeamObjects which were properly saved on the API side

            // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
            guard var conflictedObject = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                completion(.failure(error))
                return
            }

            // Note: `conflictedObject` is the BeamObject which raised conflict

            // Set `checksum` on the objects who were saved successfully as this will be used later
            var goodObjects: [T] = objects.compactMap {
                if conflictedObject.beamObjectId == $0.beamObjectId { return nil }

                var remoteObject = $0
                remoteObject.checksum = remoteBeamObjects.first(where: {
                    $0.id == remoteObject.beamObjectId
                })?.dataChecksum

                return remoteObject
            }

            // Note: `goodObjects` are the objects properly saved, with `checksum` set.

            Logger.shared.logDebug("⚠️ goodObjects: ", category: .beamObjectNetwork)
            dump(goodObjects)

            fetchAndReturn(conflictedObject) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logDebug("⚠️ inside fetchAndReturn failure", category: .beamObjectNetwork)
                    completion(.failure(error))
                case .success(let fetchedObject):
                    Logger.shared.logDebug("⚠️ inside fetchAndReturn success", category: .beamObjectNetwork)

                    Logger.shared.logDebug("⚠️ fetchedObject: ", category: .beamObjectNetwork)
                    dump(fetchedObject)

                    switch self.conflictPolicyForSave {
                    case .replace:
                        conflictedObject.previousChecksum = fetchedObject.checksum

                        do {
                            _ = try self.saveToAPI(conflictedObject) { result in
                                switch result {
                                case .failure(let error): completion(.failure(error))
                                case .success(let newSavedObject):
                                    Logger.shared.logDebug("⚠️ inside fetchAndReturn saveToAPI success", category: .beamObjectNetwork)

                                    conflictedObject.checksum = newSavedObject.checksum
                                    goodObjects.append(conflictedObject)

                                    Logger.shared.logDebug("⚠️ newSavedObject: ", category: .beamObjectNetwork)
                                    dump(newSavedObject)

                                    Logger.shared.logDebug("⚠️ goodObjects: ", category: .beamObjectNetwork)
                                    dump(goodObjects)

                                    completion(.success(goodObjects))
                                }
                            }
                        } catch {
                            completion(.failure(error))
                        }
                    case .fetchRemoteAndError:
                        completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject], goodObjects, [fetchedObject])))
                    }
                }
            }
            return
        case APIRequestError.apiErrors(let errorable):
            Logger.shared.logDebug("⚠️ errorable:", category: .beamObjectDebug)
            dump(errorable)

            // Make sure we have proper network request call, including the objects which were properly saved
            guard let remoteBeamObjects = (errorable as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects,
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

            Logger.shared.logDebug("⚠️ conflictedObjects:", category: .beamObjectDebug)
            dump(conflictedObjects)

            // Set `checksum` on the objects who were saved successfully as this will be used later
            var goodObjects: [T] = objects.compactMap {
                if objectErrorIds.contains($0.beamObjectId.uuidString.lowercased()) { return nil }

                var remoteObject = $0
                remoteObject.checksum = remoteBeamObjects.first(where: {
                    $0.id == remoteObject.beamObjectId
                })?.dataChecksum

                return remoteObject
            }

            Logger.shared.logDebug("⚠️ goodObjects:", category: .beamObjectDebug)
            dump(goodObjects)

            let group = DispatchGroup()
            let groupSemaphore = DispatchSemaphore(value: 1)
            var groupErrors: [Error] = []
            var fetchedObjects: [T] = []

            for conflictedObject in conflictedObjects {
                group.enter()

                fetchAndReturn(conflictedObject) { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logDebug("⚠️ inside fetchAndReturn failure", category: .beamObjectNetwork)
                        groupSemaphore.wait()
                        groupErrors.append(error)
                        groupSemaphore.signal()
                        group.leave()
                    case .success(let fetchedObject):
                        Logger.shared.logDebug("⚠️ fetchedObject: ", category: .beamObjectNetwork)
                        dump(fetchedObject)

                        switch self.conflictPolicyForSave {
                        case .replace:
                            do {
                                // Ugly
                                var fixedConflictedObject: T = try ( try BeamObject(conflictedObject, T.beamObjectTypeName)).decodeBeamObject()

                                fixedConflictedObject.previousChecksum = fetchedObject.checksum

                                _ = try self.saveToAPI(fixedConflictedObject) { result in
                                    switch result {
                                    case .failure(let error):
                                        groupSemaphore.wait()
                                        groupErrors.append(error)
                                        groupSemaphore.signal()
                                    case .success(let newSavedObject):
                                        Logger.shared.logDebug("⚠️ inside fetchAndReturn saveToAPI success", category: .beamObjectNetwork)

                                        Logger.shared.logDebug("⚠️ newSavedObject: ", category: .beamObjectNetwork)
                                        dump(newSavedObject)

                                        Logger.shared.logDebug("⚠️ goodObjects: ", category: .beamObjectNetwork)
                                        dump(goodObjects)

                                        Logger.shared.logDebug("⚠️ fixedConflictedObject: ", category: .beamObjectNetwork)
                                        dump(fixedConflictedObject)

                                        fixedConflictedObject.checksum = newSavedObject.checksum

                                        groupSemaphore.wait()
                                        goodObjects.append(fixedConflictedObject)
                                        groupSemaphore.signal()
                                    }
                                    group.leave()
                                }
                            } catch {
                                groupSemaphore.wait()
                                groupErrors.append(error)
                                groupSemaphore.signal()
                                group.leave()
                            }
                        case .fetchRemoteAndError:
                            groupSemaphore.wait()
                            fetchedObjects.append(fetchedObject)
                            groupSemaphore.signal()
                            group.leave()
                        }
                    }
                }
            }

            group.wait()

            guard groupErrors.isEmpty else {
                completion(.failure(BeamObjectManagerError.multipleErrors(groupErrors)))
                return
            }

            switch self.conflictPolicyForSave {
            case .replace:
                completion(.success(goodObjects))
            case .fetchRemoteAndError:
                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum(conflictedObjects, goodObjects, fetchedObjects)))
            }

            return
        default:
            break
        }

        completion(.failure(error))
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
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
            guard let beamObject = beamObjects.first(where: { $0.beamObjectId.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                completion(.failure(error))
                return
            }

            // Set `checksum` on the objects who were saved successfully as this will be used later
            var remoteFilteredBeamObjects: [BeamObject] = beamObjects.compactMap {
                if beamObject.beamObjectId == $0.beamObjectId { return nil }

                let remoteObject = $0
                remoteObject.dataChecksum = remoteBeamObjects.first(where: {
                    $0.id == remoteObject.beamObjectId
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIFailureAPIErrorsDeprecated<T: BeamObjectProtocol>(_ objects: [T],
                                                                             _ errors: [UserErrorData],
                                                                             _ completion: @escaping ((Swift.Result<[T], Error>) -> Void)) throws {
        // We have multiple errors, we're going to fetch each beamObject on the server side to include them in
        // the error we'll return to the object calling this manager
        let group = DispatchGroup()

        var resultErrors: [Error] = []
        var newObjects: [T] = []
        let lock = DispatchSemaphore(value: 1)

        for error in errors {
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let object = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                continue
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard isErrorInvalidChecksum(error) else { continue }

            group.enter()

            fetchAndReturn(object) { result in
                lock.wait()

                switch result {
                case .failure(let error): resultErrors.append(error)
                case .success(let fetchedObject):
                    do {
                        // Ugly hack to avoid `copy()` in protocol
                        var conflictedObject: T = try ( try BeamObject(object, T.beamObjectTypeName) ).decodeBeamObject()

                        switch self.conflictPolicyForSave {
                        case .fetchRemoteAndError:
                            resultErrors.append(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject], [], [fetchedObject]))
                        case .replace:
                            conflictedObject.previousChecksum = fetchedObject.checksum
                            newObjects.append(conflictedObject)
                        }
                    } catch {
                        resultErrors.append(error)
                    }
                }

                lock.signal()
                group.leave()
            }
        }

        group.wait()

        if !newObjects.isEmpty && conflictPolicyForSave == .fetchRemoteAndError ||
            !resultErrors.isEmpty && conflictPolicyForSave == .replace {
            fatalError("Should never happen")
        }

        switch conflictPolicyForSave {
        case .replace:
            do {
                _ = try saveToAPI(newObjects) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let savedObjects):

                        // TODO: might have to check checksum
                        let goodObjects = objects.filter {
                            !newObjects.map { $0.beamObjectId }.contains($0.beamObjectId)
                        }

                        completion(.success(savedObjects + goodObjects))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        case .fetchRemoteAndError:
            completion(.failure(BeamObjectManagerError.multipleErrors(resultErrors)))
        }
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

    internal func isErrorInvalidChecksum(_ error: UserErrorData) -> Bool {
        error.message == "Differs from current checksum" && error.path == ["attributes", "previous_checksum"]
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
                // Not: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving. We're decoding back what we sent, and set `previousChecksum` as the caller needs
                // to persist it
                do {
                    var savedObject: T = try beamObject.decodeBeamObject()
                    savedObject.previousChecksum = remoteBeamObject.dataChecksum

                    completion(.success(savedObject))
                } catch {
                    completion(.failure(error))
                }
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

                self.fetchAndReturn(object) { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logDebug("⚠️ inside fetchAndReturn failure", category: .beamObjectNetwork)
                        completion(.failure(error))
                    case .success(let fetchedObject):
                        Logger.shared.logDebug("⚠️ inside fetchAndReturn success", category: .beamObjectNetwork)

                        Logger.shared.logDebug("⚠️ fetchedObject: ", category: .beamObjectNetwork)
                        dump(fetchedObject)

                        do {
                            // Ugly hack to avoid `copy()` in protocol
                            var conflictedObject: T = try ( try BeamObject(object, T.beamObjectTypeName) ).decodeBeamObject()
                            switch self.conflictPolicyForSave {
                            case .replace:
                                conflictedObject.previousChecksum = fetchedObject.checksum

                                do {
                                    _ = try self.saveToAPI(conflictedObject) { result in
                                        switch result {
                                        case .failure(let error): completion(.failure(error))
                                        case .success(let newSavedObject):
                                            Logger.shared.logDebug("⚠️ inside fetchAndReturn saveToAPI success", category: .beamObjectNetwork)

                                            conflictedObject.checksum = newSavedObject.checksum

                                            Logger.shared.logDebug("⚠️ newSavedObject: ", category: .beamObjectNetwork)
                                            dump(newSavedObject)

                                            completion(.success(conflictedObject))
                                        }
                                    }
                                } catch {
                                    completion(.failure(error))
                                }
                            case .fetchRemoteAndError:
                                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject], [], [fetchedObject])))
                            }
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
    internal func fetchAndReturn<T: BeamObjectProtocol>(_ object: T,
                                                        _ completion: @escaping (Result<T, Error>) -> Void) {
        Logger.shared.logDebug("⚠️ inside fetchAndReturn", category: .beamObjectNetwork)

        fetchObject(object.beamObjectId) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // This happened during tests, but could happen again if you have the same IDs for 2 different objects
                guard remoteBeamObject.beamObjectType == T.beamObjectTypeName else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectTypeName)")))
                    return
                }

                do {
                    let remoteObject: T = try remoteBeamObject.decodeBeamObject()

//                    // Very ugly hack to not have to enforce a `copy` within the protocol
//                    var newObject: T = try (try BeamObject(object, T.beamObjectTypeName)).decodeBeamObject()
//
//                    // TODO: 1 of the 2 needed
//                    newObject.previousChecksum = remoteObject.checksum
//                    newObject.checksum = remoteObject.checksum

                    completion(.success(remoteObject))
                } catch {
                    completion(.failure(BeamObjectManagerError.decodingError(remoteBeamObject)))
                }
            }
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy<T: BeamObjectProtocol>(_ object: T,
                                                                                  _ completion: @escaping (Result<T, Error>) -> Void) {

        guard let beamObject = try? BeamObject(object, T.beamObjectTypeName) else {
            completion(.failure(BeamObjectManagerError.encodingError))
            return
        }

        Logger.shared.logDebug("⚠️ inside fetchAndReturnErrorBasedOnConflictPolicy", category: .beamObjectNetwork)

        fetchObject(beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // This happened during tests, but could happen again if you have the same IDs for 2 different objects
                guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
                    completion(.failure(BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)))
                    return
                }

                let newBeamObject = beamObject.copy()
                newBeamObject.previousChecksum = remoteBeamObject.dataChecksum

                switch self.conflictPolicyForSave {
                case .replace:
                    do {
                        var newObject: T = try newBeamObject.decodeBeamObject()
                        newObject.previousChecksum = remoteBeamObject.dataChecksum
                        completion(.success(newObject))
                    } catch {
                        completion(.failure(BeamObjectManagerError.decodingError(newBeamObject)))
                    }
                case .fetchRemoteAndError:
                    do {
                        var newObject: T = try newBeamObject.decodeBeamObject()
                        newObject.previousChecksum = remoteBeamObject.dataChecksum

                        var decodedObject: T = try remoteBeamObject.decodeBeamObject()
                        decodedObject.previousChecksum = remoteBeamObject.dataChecksum

                        Logger.shared.logDebug("⚠️ inside fetchAndReturnErrorBasedOnConflictPolicy.fetchRemoteAndError",
                                               category: .beamObjectNetwork)

                        fatalError("OOPS")
//                        completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum(decodedObject)))
//                        completion(.success(decodedObject))
                    } catch {
                        completion(.failure(BeamObjectManagerError.decodingError(remoteBeamObject)))
                    }
                }
            }
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject,
                                                           _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        fetchObject(beamObject) { fetchResult in
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

    internal func fetchObject(_ beamObject: BeamObject,
                              _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(beamObject.id, completion)
        } catch {
            completion(.failure(error))
        }
    }

    internal func fetchObject(_ id: UUID,
                              _ completion: @escaping (Result<BeamObject, Error>) -> Void) {
        let fetchRequest = BeamObjectRequest()
        do {
            try fetchRequest.fetch(id, completion)
        } catch {
            completion(.failure(error))
        }
    }

    func delete(_ id: UUID, _ completion: ((Swift.Result<BeamObject, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        Self.networkRequests[id]?.cancel()
        let request = BeamObjectRequest()
        Self.networkRequests[id] = request

        do {
            try request.delete(id) { result in
                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success(let object): completion?(.success(object))
                }
            }
        } catch {
            completion?(.failure(error))
        }
    }

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

// swiftlint:enable file_length
