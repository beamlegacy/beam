import Foundation
import BeamCore
// swiftlint:disable file_length

extension BeamObjectManagerDelegate {
    func saveAllOnBeamObjectApi(force: Bool = false, progress: ((Float) async -> Void)? = nil) async throws -> (Int, Date?) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        self.willSaveAllOnBeamObjectApi()

        // swiftlint:disable:next date_init
        let localTimer = Date()

        var mostRecentUpdatedAt = Date(timeIntervalSince1970: 0)
        var savedCount = 0
        var objects: [BeamObjectType] = []

        let objectsToSaveWithoutChangedObjects = try allObjects(updatedSince: Persistence.Sync.BeamObjects.last_updated_at)
        objectsToSaveWithoutChangedObjects.forEach {
            changedObjects[$0.beamObjectId] = $0
        }

        let objectsToSave = changedObjects.values

        changedObjects.removeAll()

        var chunk = objectsToSave.count / 100
        let min = 1000
        let max = 10000

        if chunk > max {
            chunk = max
        } else if chunk < min {
            chunk = min
        }

        let save = {
            let savedObjects = try await self.saveOnBeamObjectsAPI(objects, force: force)
            savedCount += savedObjects.count
            objects = []

            let percentage = Float(savedCount) / Float(objectsToSave.count) * 100.0
            await progress?(percentage)
        }

        for object in objectsToSave {
            if object.updatedAt > mostRecentUpdatedAt {
                mostRecentUpdatedAt = object.updatedAt
            }

            objects.append(object)

            if objects.count >= chunk {
                try await save()
            }
        }

        if objects.count > 0 {
            try await save()
        } else {
            await progress?(100)
        }

        Logger.shared.logDebug("\(Self.BeamObjectType.beamObjectType.rawValue) manager returned \(savedCount) objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)
        return (savedCount, mostRecentUpdatedAt)
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    func saveOnBeamObjectsAPI(_ objects: [BeamObjectType],
                              force: Bool = false,
                              deep: Int = 0) async throws -> [BeamObjectType] {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        guard deep < 3 else {
            throw BeamObjectManagerDelegateError.nestedTooDeep
        }

        if Thread.isMainThread, Configuration.env != .test {
            Logger.shared.logError("Please don't use saveOnBeamObjectsAPI in the main thread. Create your own DispatchQueue instead.",
                                   category: .beamObjectNetwork)
            assert(false)
        }

        let beamObjectTypes = Set(objects.map { type(of: $0).beamObjectType.rawValue }).joined(separator: ", ")
        Logger.shared.logDebug("saveOnBeamObjectsAPI called with \(objects.count) objects of type \(beamObjectTypes)",
                               category: .beamObjectNetwork)

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        let uuids = objects.map { $0.beamObjectId }
        let semaphores = BeamObjectManagerCall.objectsSemaphores(uuids: uuids)
        semaphores.forEach {
            let semaResult = $0.wait(timeout: DispatchTime.now() + .seconds(600))

            if case .timedOut = semaResult {
                Logger.shared.logError("network semaphore expired", category: .beamObjectNetwork)
            }
        }

        do {
            let remoteObjects = try await objectManager.saveToAPI(objects, force: force, requestUploadType: Self.uploadType)
            return self.saveOnBeamObjectsAPISuccess(uuids: uuids,
                                                    remoteObjects: remoteObjects,
                                                    semaphores: semaphores)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
            return try await saveOnBeamObjectsAPIError(objects: objects,
                                             uuids: uuids,
                                             semaphores: semaphores,
                                             deep: deep,
                                             error: error)
        }
    }

    internal func saveOnBeamObjectsAPISuccess(uuids: [UUID],
                                              remoteObjects: [BeamObjectType],
                                              semaphores: [DispatchSemaphore]) -> [BeamObjectType] {

        BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
        semaphores.forEach { $0.signal() }

        return remoteObjects
    }

    internal func saveOnBeamObjectsAPIError(objects: [BeamObjectType],
                                            uuids: [UUID],
                                            semaphores: [DispatchSemaphore],
                                            deep: Int,
                                            error: Error) async throws -> [BeamObjectType] {
        Logger.shared.logError("Could not save all \(objects.count) \(BeamObjectType.beamObjectType) objects: \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        if case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error {
            BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
            semaphores.forEach { $0.signal() }

            return try await self.manageInvalidChecksum(error, deep)
        }

        // We don't manage anything else than `BeamObjectManagerError.multipleErrors`
        guard case BeamObjectManagerError.multipleErrors(let errors) = error else {
            BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
            semaphores.forEach { $0.signal() }

            throw error
        }

        let results = try await self.manageMultipleErrors(objects, errors)

        BeamObjectManagerCall.deleteObjectsSemaphores(uuids: uuids)
        semaphores.forEach { $0.signal() }

        return results
    }

    @discardableResult
    func deleteFromBeamObjectAPI(object: BeamObjectType) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        try await objectManager.delete(object: object)

        return true
    }

    @discardableResult
    func deleteFromBeamObjectAPI(objects: [BeamObjectType]) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        var errors: [Error] = []
        let objectManager = BeamObjectManager()

        for object in objects {
            do {
                try await objectManager.delete(object: object)
            } catch {
                errors.append(error)
            }
        }

        guard errors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(errors)
        }
        return true
    }

    @discardableResult
    func deleteAllFromBeamObjectAPI() async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        try await objectManager.deleteAll(BeamObjectType.beamObjectType)
        return true
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func refreshFromBeamObjectAPI(_ object: BeamObjectType,
                                  _ forced: Bool = false) async throws -> BeamObjectType? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        let semaphore = BeamObjectManagerCall.objectSemaphore(uuid: object.beamObjectId)
        semaphore.wait()

        guard !forced else {
            do {
                defer {
                    BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                    semaphore.signal()
                }
                let remoteObject = try await objectManager.fetchObject(object)
                return remoteObject
            } catch {
                if case APIRequestError.notFound = error {
                    return nil
                }
                throw error
            }
        }

        do {
            defer {
                BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
                semaphore.signal()
            }
            let remoteChecksum = try await objectManager.fetchObjectChecksum(object)
            let beamObject = try BeamObject(object)

            guard let remoteChecksum = remoteChecksum, remoteChecksum != beamObject.dataChecksum else {
                return nil
            }

            let remoteObject = try await objectManager.fetchObject(object)
            return remoteObject
        } catch {
            if case APIRequestError.notFound = error {
                return nil
            }
            throw error
        }
    }

    @discardableResult
    func fetchAllFromBeamObjectAPI(raisePrivateKeyError: Bool = false) async throws -> [BeamObjectType] {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        let objectManager = BeamObjectManager()

        return try await objectManager.fetchAllObjects(raisePrivateKeyError: raisePrivateKeyError)
    }

    func saveOnBeamObjectAPI(_ object: BeamObjectType,
                             force: Bool = false) async throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        if Thread.isMainThread, Configuration.env != .test {
            Logger.shared.logError("Please don't use saveOnBeamObjectAPI in the main thread. Create your own DispatchQueue instead.",
                                   category: .beamObjectNetwork)
            assert(false)
        }

        let objectManager = BeamObjectManager()
        objectManager.conflictPolicyForSave = Self.conflictPolicy

        Logger.shared.logDebug("saveOnBeamObjectAPI called. Object \(object.beamObjectId), type: \(type(of: object).beamObjectType)",
                               category: .beamObjectNetwork)

        let fullSyncRunning = BeamObjectManager.fullSyncRunning.load(ordering: .relaxed) == true
        if fullSyncRunning {
            addChangedObject(object)
            return
        }

        let semaphore = BeamObjectManagerCall.objectSemaphore(uuid: object.beamObjectId)
        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))

        if case .timedOut = semaResult {
            Logger.shared.logError("network semaphore expired for Object \(object.beamObjectId), type: \(type(of: object).beamObjectType)",
                                   category: .beamObjectNetwork)
        }

        do {
            let remoteObject = try await objectManager.saveToAPI(object, force: force, requestUploadType: Self.uploadType)
            _ = self.saveOnBeamObjectAPISuccess(object: object,
                                                remoteObject: remoteObject,
                                                semaphore: semaphore)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
            _ = try await self.saveOnBeamObjectAPIError(object: object,
                                                        semaphore: semaphore,
                                                        error: error)
        }
    }

    internal func saveOnBeamObjectAPISuccess(object: BeamObjectType,
                                             remoteObject: BeamObjectType,
                                             semaphore: DispatchSemaphore) -> BeamObjectType {

        BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
        semaphore.signal()

        return remoteObject
    }

    internal func saveOnBeamObjectAPIError(object: BeamObjectType,
                                           semaphore: DispatchSemaphore,
                                           error: Error) async throws -> BeamObjectType {
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum = error else {
            BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
            semaphore.signal()

            throw error
        }

        // When dealing with invalid checksum, we will retry the `saveOnBeamObjectAPI` so semaphore must be unlocked
        // first
        BeamObjectManagerCall.deleteObjectSemaphore(uuid: object.beamObjectId)
        semaphore.signal()

        let objects = try await self.manageInvalidChecksum(error, 0)
        guard let newObject = objects.first, objects.count == 1 else {
            throw BeamObjectManagerDelegateError.runtimeError("Had more than one object back")
        }
        return newObject
    }

    internal func manageInvalidChecksum(_ error: Error,
                                        _ deep: Int) async throws -> [BeamObjectType] {
        // Early return except for checksum issues.
        guard case BeamObjectManagerObjectError<BeamObjectType>.invalidChecksum(let conflictedObjects,
                                                                                let goodObjects,
                                                                                let remoteObjects) = error else {
            throw error
        }

        var mergedObjects: [BeamObjectType] = []

        for conflictedObject in conflictedObjects {
            if let remoteObject = remoteObjects.first(where: { $0.beamObjectId == conflictedObject.beamObjectId }) {
                let mergedObject = try manageConflict(conflictedObject, remoteObject)
                mergedObjects.append(mergedObject)
            } else {
                // The remote object doesn't exist, we can just resend it without a `previousChecksum` to create it
                // server-side
                let mergedObject = try conflictedObject.copy()

                try BeamObjectChecksum.deletePreviousChecksum(object: mergedObject)
                mergedObjects.append(mergedObject)
            }
        }

        let savedRemoteObjects = try await self.saveOnBeamObjectsAPI(mergedObjects, force: true, deep: deep + 1)
        var allObjects: [BeamObjectType] = []
        allObjects.append(contentsOf: goodObjects)
        allObjects.append(contentsOf: savedRemoteObjects)

        try self.saveObjectsAfterConflict(savedRemoteObjects)
        try BeamObjectChecksum.savePreviousChecksums(objects: savedRemoteObjects)
        return allObjects
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func manageMultipleErrors(_ objects: [BeamObjectType],
                                       _ errors: [Error]) async throws -> [BeamObjectType] {

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
                throw BeamObjectManagerError.multipleErrors(errors)
            }

            guard let conflictedObject = conflictedObjects.first, conflictedObjects.count == 1 else {
                throw BeamObjectManagerDelegateError.runtimeError("Had more than one object back")
            }

            guard let remoteObject = remoteObjects.first, remoteObjects.count == 1 else {
                throw BeamObjectManagerDelegateError.runtimeError("Had more than one object back")
            }

            let mergedObject = try manageConflict(conflictedObject, remoteObject)
            goodObjects.append(contentsOf: errorGoodObjects)
            newObjects.append(mergedObject)
        }

        let newObjectsSaved = try await self.saveOnBeamObjectsAPI(newObjects)
        try self.saveObjectsAfterConflict(newObjectsSaved)
        return goodObjects + newObjectsSaved
    }
}
