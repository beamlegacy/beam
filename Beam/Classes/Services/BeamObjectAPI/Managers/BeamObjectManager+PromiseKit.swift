import Foundation
import PromiseKit
import BeamCore

// swiftlint:disable file_length

extension BeamObjectManager {
    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI() -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        let promise: Promise = beamRequest.fetchAll(receivedAtAfter: lastReceivedAt)

        // TODO: add a way to cancel this request

        return promise.map(on: backgroundQueue) { beamObjects in
            guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
                return true
            }

            if let mostRecentReceivedAt = beamObjects.compactMap({ $0.updatedAt }).sorted().last {
                Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt). \(beamObjects.count) beam objects fetched.",
                                       category: .beamObjectNetwork)
                var objectIds = beamObjects.map { $0.id.uuidString.lowercased() }
                if objectIds.count > 10 {
                    objectIds = Array(objectIds[0...10])
                    objectIds.append("...")
                }
                Logger.shared.logDebug("objects IDs: \( objectIds.joined(separator: ", "))",
                                       category: .beamObjectNetwork)
            }

            try self.parseFilteredObjects(self.filteredObjects(beamObjects))
            return true
        }.recover(on: backgroundQueue) { error -> Promise<Bool> in
            let message = "Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support."
            Logger.shared.logError(message, category: .beamObject)
            if Configuration.env == .debug {
                AppDelegate.showMessage(message)
            }
            return .value(false)
        }
    }
}

// MARK: - BeamObjectProtocol
extension BeamObjectManager {
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T], force: Bool = false) -> Promise<[T]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        var beamObjects: [BeamObject]

        do {
            let checksums = BeamObjectChecksum.previousChecksums(objects: objects)

            beamObjects = try objects.map {
                let result = try BeamObject(object: $0)
                result.previousChecksum = checksums[$0.beamObjectId]

                return result
            }
        } catch {
            return Promise(error: error)
        }

        let promise: Promise = request.saveAll(beamObjects)
        // TODO: add a way to cancel request

        return promise.map(on: backgroundQueue) { _ in
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjects)

            return objects
        }.recover { error -> Promise<[T]> in
            switch error {
            case APIRequestError.beamObjectInvalidChecksum:
                Logger.shared.logWarning("beamObjectInvalidChecksum -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                         category: .beamObject)
                return self.saveToAPIFailureBeamObjectInvalidChecksum(objects, error)
            case APIRequestError.apiErrors:
                Logger.shared.logWarning("APIRequestError.apiErrors -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                         category: .beamObject)

                return self.saveToAPIFailureApiErrors(objects, error)
            default: break
            }

            throw error
        }
    }

    internal func saveToAPIFailureBeamObjectInvalidChecksum<T: BeamObjectProtocol>(_ objects: [T],
                                                                                   _ error: Error) -> Promise<[T]> {
        guard case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects) = error,
              let remoteBeamObjects = (updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects else {
            return Promise(error: error)
        }

        /*
         In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
         to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
         objects into `remoteObjects` to resend them back in the completion handler
         */

        // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
        guard var conflictedObject = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
            return Promise(error: error)
        }

        let goodObjects: [T] = extractGoodObjects(objects, conflictedObject, remoteBeamObjects)

        var fetchedObject: T?
        do {
            fetchedObject = try fetchObject(conflictedObject)
        } catch APIRequestError.notFound {
        } catch {
            return Promise(error: error)
        }

        switch self.conflictPolicyForSave {
        case .replace:
            do {
                if let fetchedObject = fetchedObject {
                    conflictedObject = manageConflict(conflictedObject, fetchedObject)
                    try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                } else {
                    try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                }
            } catch {
                return Promise(error: error)
            }

            let promise: Promise<T> = saveToAPI(conflictedObject)

            return promise.map(on: backgroundQueue) { _ in
                return goodObjects + [conflictedObject]
            }
        case .fetchRemoteAndError:
            let error = BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                        goodObjects,
                                                                        [fetchedObject].compactMap { $0 })
            return Promise(error: error)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func saveToAPIFailureApiErrors<T: BeamObjectProtocol>(_ objects: [T],
                                                                   _ error: Error) -> Promise<[T]> {
        guard case APIRequestError.apiErrors(let errorable) = error,
              let remoteBeamObjects = (errorable as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects,
              let errors = errorable.errors else {
            return Promise(error: error)
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

        let goodObjects: [T] = extractGoodObjects(objects, objectErrorIds, remoteBeamObjects)

        let fetchObjectsPromise: Promise<[T]> = fetchObjects(conflictedObjects, storePreviousChecksum: conflictPolicyForSave == .replace)

        return fetchObjectsPromise.then(on: backgroundQueue) { fetchedConflictedObjects -> Promise<[T]> in
            switch self.conflictPolicyForSave {
            case .replace:
                let toSaveObjects: [T] = try conflictedObjects.compactMap {
                    let conflictedObject = $0

                    let fetchedObject: T? = fetchedConflictedObjects.first(where: {
                        $0.beamObjectId == conflictedObject.beamObjectId
                    })

                    if let fetchedObject = fetchedObject {
                        try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                        return self.manageConflict(conflictedObject, fetchedObject)
                    }

                    try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                    return conflictedObject
                }

                let promise: Promise<[T]> = self.saveToAPI(toSaveObjects)
                let result: Promise<[T]> = promise.map(on: self.backgroundQueue) { _ in
                    return goodObjects + toSaveObjects
                }

                return result
            case .fetchRemoteAndError:
                let error = BeamObjectManagerObjectError<T>.invalidChecksum(conflictedObjects,
                                                                            goodObjects,
                                                                            fetchedConflictedObjects)
                throw error
            }
        }
    }

    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T], storePreviousChecksum: Bool = false) -> Promise<[T]> {
        fetchBeamObjects(objects: objects).map(on: backgroundQueue) { remoteBeamObjects in
            if storePreviousChecksum {
                try BeamObjectChecksum.savePreviousChecksums(beamObjects: remoteBeamObjects)
            }
            let result: [T] = try self.beamObjectsToObjects(remoteBeamObjects)
            return result
        }
    }

    /// Fetch all remote objects
    func fetchAllObjects<T: BeamObjectProtocol>() -> Promise<[T]> {
        fetchBeamObjects(beamObjectType: T.beamObjectType.rawValue).map(on: backgroundQueue) { remoteBeamObjects in
            try self.beamObjectsToObjects(remoteBeamObjects)
        }
    }

    internal func fetchBeamObjects<T: BeamObjectProtocol>(objects: [T]) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()

        return request.fetchAll(ids: objects.map { $0.beamObjectId },
                                beamObjectType: T.beamObjectType.rawValue)
    }

    internal func fetchBeamObjects(beamObjects: [BeamObject]) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()

        return request.fetchAll(ids: beamObjects.map { $0.id })
    }

    internal func fetchBeamObjects(ids: [UUID]) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()
        return request.fetchAll(ids: ids)
    }

    internal func fetchBeamObjects(beamObjectType: String) -> Promise<[BeamObject]> {
        let request = BeamObjectRequest()
        return request.fetchAll(beamObjectType: beamObjectType)
    }

    func saveToAPI<T: BeamObjectProtocol>(_ object: T) -> Promise<T> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        var beamObject: BeamObject

        do {
            beamObject = try BeamObject(object: object)
        } catch { return Promise(error: error) }

        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        let request = BeamObjectRequest()
        let promise: Promise = request.save(beamObject)

        return promise.map(on: backgroundQueue) { _ in
            // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
            // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
            // and set their `previousChecksum`

            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)

            // We'll use `copy()` when it's faster and doesn't encode/decode
            let savedObject: T = try beamObject.decodeBeamObject()
            return savedObject
        }.recover(on: backgroundQueue) { error -> Promise<T> in
            self.saveToAPIFailure(object, beamObject, error)
        }
    }

    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ object: T,
                                                          _ beamObject: BeamObject,
                                                          _ error: Error) -> Promise<T> {
        Logger.shared.logError("Could not save \(object): \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        // Early return except for checksum issues.
        guard case APIRequestError.beamObjectInvalidChecksum = error else {
            return Promise(error: error)
        }

        Logger.shared.logWarning("Invalid Checksum. Local previousChecksum: \(beamObject.previousChecksum ?? "-")",
                                 category: .beamObjectNetwork)

        do {
            var fetchedObject: T?
            do {
                fetchedObject = try fetchObject(object)
            } catch APIRequestError.notFound {
                try BeamObjectChecksum.deletePreviousChecksum(object: object)
            }
            var conflictedObject: T = try object.copy()

            switch self.conflictPolicyForSave {
            case .replace:
                if let fetchedObject = fetchedObject {
                    conflictedObject = manageConflict(conflictedObject, fetchedObject)
                    try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                } else {
                    try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                }

                let promise: Promise<T> = saveToAPI(conflictedObject)

                return promise.map(on: backgroundQueue) { _ in
                    return conflictedObject
                }
            case .fetchRemoteAndError:
                let error = BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                            [],
                                                                            [fetchedObject].compactMap { $0 })
                return Promise(error: error)
            }
        } catch {
            return Promise(error: error)
        }
    }

    func fetchObject<T: BeamObjectProtocol>(object: T) -> Promise<T> {
        let promise: Promise = fetchBeamObject(object: object)

        return promise.map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
            }

            return try remoteBeamObject.decodeBeamObject()
        }
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(object: T) -> Promise<Date?> {
        fetchMinimalBeamObject(object: object).map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
            }
            return remoteBeamObject.updatedAt
        }
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(object: T) -> Promise<String?> {
        fetchMinimalBeamObject(object: object).map(on: backgroundQueue) { remoteBeamObject in
            // Check if you have the same IDs for 2 different object types
            guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
            }
            return remoteBeamObject.dataChecksum
        }
    }
}

// MARK: - BeamObject
extension BeamObjectManager {
    func saveToAPI(_ beamObjects: [BeamObject]) -> Promise<[BeamObject]> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

        beamObjects.forEach {
            $0.previousChecksum = checksums[$0]
        }

        let request = BeamObjectRequest()
        let promise: Promise = request.saveAll(beamObjects)

        return promise.map(on: backgroundQueue) { updateBeamObjects in
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjects)
            return updateBeamObjects
        }.recover(on: backgroundQueue) { error -> Promise<[BeamObject]> in
            self.saveToAPIBeamObjectsFailure(beamObjects, error)
        }
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              _ error: Error) -> Promise<[BeamObject]> {
        Logger.shared.logError("Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects):
            /*
             In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
             to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
             objects into `remoteObjects` to resend them back in the completion handler
             */

            guard let updateBeamObjects = updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects else {
                return Promise(error: error)
            }

            // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                return Promise(error: error)
            }

            let goodObjects = beamObjects.filter {
                beamObject.id != $0.id
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            let promise: Promise<BeamObject> = fetchAndReturnErrorBasedOnConflictPolicy(beamObject)
            return promise.then(on: backgroundQueue) {
                self.saveToAPI($0)
            }.map(on: self.backgroundQueue) { _ in
                try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            }.map(on: self.backgroundQueue) { _ in
                return goodObjects + [beamObject]
            }
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            return saveToAPIFailureAPIErrors(beamObjects, errors)
        default:
            break
        }

        return Promise(error: error)
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject) -> Promise<BeamObject> {
        let promise: Promise<BeamObject> = fetchBeamObject(beamObject: beamObject)

        return promise.then(on: backgroundQueue) { remoteBeamObject -> Promise<BeamObject> in
            // This happened during tests, but could happen again if you have the same IDs for 2 different objects
            guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
                throw BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)
            }

            switch self.conflictPolicyForSave {
            case .replace:

                try BeamObjectChecksum.savePreviousChecksum(beamObject: remoteBeamObject)
                let newBeamObject = self.manageConflict(beamObject, remoteBeamObject)
                return .value(newBeamObject)
            case .fetchRemoteAndError:
                throw BeamObjectManagerError.invalidChecksum(remoteBeamObject)
            }
        }.recover(on: backgroundQueue) { error -> Promise<BeamObject> in
            /*
             We tried fetching the remote beam object but it doesn't exist, we set `previousChecksum` to `nil`
             */
            if case APIRequestError.notFound = error {
                try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)

                switch self.conflictPolicyForSave {
                case .replace:
                    return .value(beamObject)
                case .fetchRemoteAndError:
                    throw BeamObjectManagerError.invalidChecksum(beamObject)
                }
            }
            throw error
        }
    }

    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObject],
                                            _ errors: [UserErrorData]) -> Promise<[BeamObject]> {
        let promises: [Promise<BeamObject>] = errors.compactMap { error in
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                return nil
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard error.isErrorInvalidChecksum else { return nil }

            return fetchAndReturnErrorBasedOnConflictPolicy(beamObject)
        }

        return when(fulfilled: promises).then(on: self.backgroundQueue) { newBeamObjects in
            self.saveToAPI(newBeamObjects)
        }
    }

    func saveToAPI(_ beamObject: BeamObject) -> Promise<BeamObject> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        let promise: Promise = request.save(beamObject)

        return promise.map(on: backgroundQueue) { _ in
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            return beamObject
        }.recover(on: backgroundQueue) { error -> Promise<BeamObject> in
            // Early return except for checksum issues.
            guard case APIRequestError.beamObjectInvalidChecksum = error else {
                Logger.shared.logError("Could not save \(beamObject): \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                throw error
            }

            Logger.shared.logWarning("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                     category: .beamObjectNetwork)

            let result: Promise<BeamObject> = self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject)

            return result.then(on: self.backgroundQueue) { newBeamObject -> Promise<BeamObject> in
                Logger.shared.logWarning("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                         category: .beamObjectNetwork)
                Logger.shared.logWarning("Overwriting local object with remote checksum",
                                         category: .beamObjectNetwork)
                try BeamObjectChecksum.savePreviousChecksum(beamObject: newBeamObject)
                return self.saveToAPI(newBeamObject)
            }
        }
    }

    internal func fetchBeamObject(beamObject: BeamObject) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetch(beamObject: beamObject)
    }

    internal func fetchBeamObject<T: BeamObjectProtocol>(object: T) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetch(object: object)
    }

    internal func fetchMinimalBeamObject(beamObject: BeamObject) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetchMinimalBeamObject(beamObject: beamObject)
    }

    internal func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T) -> Promise<BeamObject> {
        let request = BeamObjectRequest()
        return request.fetchMinimalBeamObject(object: object)
    }

    func delete(beamObject: BeamObject, raise404: Bool = false) -> Promise<BeamObject?> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()

        return request.delete(beamObject: beamObject)
            .map(on: backgroundQueue) { _ in
                try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)
                return beamObject
            }.recover(on: backgroundQueue) { error -> Promise<BeamObject?> in
            if raise404 || !BeamError.isNotFound(error) {
                return .value(nil)
            }
            throw error
        }
    }

    func delete<T: BeamObjectProtocol>(object: T, raise404: Bool = false) -> Promise<T?> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()

        return request.delete(object: object)
            .map(on: backgroundQueue) { _ in
                try BeamObjectChecksum.deletePreviousChecksum(object: object)
                return object
            }.recover(on: backgroundQueue) { error -> Promise<T?> in
                if raise404 || !BeamError.isNotFound(error) {
                    return .value(nil)
                }
                throw error
            }
    }

    func deleteAll(_ beamObjectType: BeamObjectObjectType? = nil) -> Promise<Bool> {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            return Promise(error: BeamObjectManagerError.notAuthenticated)
        }

        let request = BeamObjectRequest()
        return request.deleteAll(beamObjectType: beamObjectType)
    }
}
