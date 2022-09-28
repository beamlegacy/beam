import Foundation
import BeamCore
import Atomics

extension BeamObjectManager {
    @MainActor
    func syncAllFromAPI(force: Bool = false, delete: Bool = true, prepareBeforeSaveAll: (() -> Void)? = nil) async throws {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let alreadyRunning = lock { () -> Bool in
            if fullSyncRunning { return true }
            fullSyncRunning = true
            return false
        }

        guard !alreadyRunning else {
            throw BeamObjectManagerError.fullSyncAlreadyRunning
        }

        do {
            defer {
                disableSendingObjects = false
            }
            disableSendingObjects = true

            synchronizationStatus = .downloading(0)
            try await fetchAllByChecksumsFromAPI(force: force)
            synchronizationStatus = .downloading(100)

            try Task.checkCancellation()

            if let prepareBeforeSaveAll = prepareBeforeSaveAll {

                Logger.shared.logDebug("syncAllFromAPI: calling prepareBeforeSaveAll",
                                       category: .sync)
                prepareBeforeSaveAll()
            }

            let localTimer = Date()
            Logger.shared.logDebug("syncAllFromAPI: calling saveAllToAPI",
                                   category: .sync)
            synchronizationStatus = .uploading(0)
            let objectsCount = try await self.saveAllToAPI(force: force)
            synchronizationStatus = .uploading(100)

            // Save all changed objects.
            Logger.shared.logDebug("syncAllFromAPI: saving changed objects", category: .sync, localTimer: localTimer)

            while true {
                for (_, manager) in managerInstances {
                    do {
                        try await manager.saveChangedObjects()
                    } catch {
                        Logger.shared.logError("syncAllFromAPI: error while saving changed objects for \(type(of: manager)). \(error)",
                                               category: .sync,
                                               localTimer: localTimer)
                    }
                }
                let done = lock { () -> Bool in
                    if managerInstances.values.allSatisfy({ $0.isChangedObjectsEmpty() }) {
                        synchronizationStatus = .finished
                        fullSyncRunning = false
                        return true
                    }
                    return false
                }
                if done {
                    break
                }
            }
            Logger.shared.logDebug("syncAllFromAPI: Called saveAllToAPI, saved \(objectsCount) objects",
                                   category: .sync,
                                   localTimer: localTimer)
        } catch {
            synchronizationStatus = .failure(error)
            lock { fullSyncRunning = false }
            throw error
        }
    }

    @discardableResult
    func saveAllToAPI(force: Bool = false) async throws -> Int {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        var errors: [Error] = []
        var savedObjects = 0
        // Just a very old date as default (10 years)
        var mostRecentUpdatedAt: Date = Persistence.Sync.BeamObjects.last_updated_at ?? (BeamDate.now.addingTimeInterval(-(60*60*24*31*12*10)))
        var mostRecentUpdatedAtChanged = false

        if let updatedAt = Persistence.Sync.BeamObjects.last_updated_at {
            Logger.shared.logDebug("Using updatedAt for BeamObjects API call: \(updatedAt)", category: .beamObjectNetwork)
        }

        /*
         IMPORTANT: We want to save in the order potentially needed by another device, which is the same as used
         for parsing
         */

        final class SimpleProgressReporter: @unchecked Sendable {
            private let lock = NSLock()
            private var managers: [BeamObjectObjectType: Float] = [:]
            private let size: Float
            private let publish: (Float) -> Void

            init(size: Int, publish: @escaping (Float) -> Void) {
                self.size = Float(size)
                self.publish = publish
            }

            func storeProgress(_ beamObjectObjectType: BeamObjectObjectType, _ progress: Float) {
                let average = lock { () -> Float in
                    managers[beamObjectObjectType] = progress
                    return managers.values.map({ $0 / size}).reduce(0, +)
                }
                publish(average)
            }
        }

        let progress = SimpleProgressReporter(size: managerInstances.count, publish: { progress in
            self.synchronizationStatus = .uploading(progress)
        })

        await withTaskGroup(of: Swift.Result<(Int, Date?), Error>.self, body: { group in
            for (beamObjectObjectType, manager) in self.managerInstances {
                group.addTask {
                    let localTimer = Date()
                    defer {
                        Logger.shared.logDebug("saveAllToAPI using \(manager) done",
                                               category: .beamObjectNetwork,
                                               localTimer: localTimer)
                    }
                    do {
                        Logger.shared.logDebug("saveAllToAPI using \(manager)", category: .beamObjectNetwork)
                        let result = try await manager.saveAllOnBeamObjectApi(force: force,
                                                                              progress: { percentage in
                            progress.storeProgress(beamObjectObjectType, percentage)
                        })
                        return .success(result)
                    } catch {
                        progress.storeProgress(beamObjectObjectType, 100)
                        return .failure(error)
                    }
                }
            }
            for await result in group {
                switch result {
                case .failure(let error):
                    errors.append(error)
                case .success(let countAndDate):
                    savedObjects += countAndDate.0

                    if let updatedAt = countAndDate.1, updatedAt > mostRecentUpdatedAt {
                        mostRecentUpdatedAt = updatedAt
                        mostRecentUpdatedAtChanged = true
                    }
                }
            }
        })

        if mostRecentUpdatedAtChanged {
            Logger.shared.logDebug("Updating last_updated_at from \(String(describing: Persistence.Sync.BeamObjects.last_updated_at)) to \(mostRecentUpdatedAt)",
                                   category: .beamObjectNetwork)
            Persistence.Sync.BeamObjects.last_updated_at = mostRecentUpdatedAt
        }

        guard errors.isEmpty else {
            throw BeamObjectManagerError.multipleErrors(errors)
        }

        return savedObjects
    }
    // Will fetch remote checksums for objects since `lastReceivedAt` and then fetch objects for which we have a different
    // checksum locally, and therefor must be fetched from the API. This allows for a faster fetch since most of the time
    // we might already have those object locally if they had been sent and updated from the same device
    func fetchAllByChecksumsFromAPI(force: Bool = false) async throws {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = force ? nil : Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous lastReceivedAt for BeamObjects API call, skip checksums",
                                   category: .beamObjectNetwork)

            try await self.fetchAllFromAPI()
            return
        }

        var localTimer = Date()

        let beamObjects = try await beamRequest.fetchAllChecksums(receivedAtAfter: lastReceivedAt,
                                                                  skipDeleted: Persistence.Sync.BeamObjects.last_received_at == nil)

        // To make sure we fetch `receivedAt` as it's needed for properly skipping those already fetched objects later
        if !beamObjects.isEmpty {
            assert(beamObjects.first?.receivedAt != nil)
        }

        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        guard lastReceivedAt == nil || !beamObjects.isEmpty else {
            Logger.shared.logDebug("fetchAllByChecksumsFromAPI: 0 beam object checksums fetched",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return
        }

        Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(beamObjects.count) beam object checksums fetched",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)
        synchronizationStatus = .downloading(33)

        do {
            localTimer = Date()
            let changedObjects = self.parseObjectChecksums(beamObjects)

            synchronizationStatus = .downloading(66)

            Logger.shared.logDebug("parsed \(beamObjects.count) checksums, got \(changedObjects.count) objects after",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)

            localTimer = Date()

            let ids: [UUID] = changedObjects.map { $0.id }

            guard !ids.isEmpty else {
                if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
                    Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                    Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) checksums",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)
                }
                return
            }

            try await self.fetchAllFromAPI(ids: ids)
        } catch {
            let message = "Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support."
            Logger.shared.logError(message, category: .beamObject)
            if Configuration.env == .debug {
                AppDelegate.showMessage(message)
            }
            throw error
        }
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI() async throws {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        try await fetchAllFromAPI(lastReceivedAt: lastReceivedAt)
    }

    private func fetchAllFromAPI(lastReceivedAt: Date? = nil,
                                 ids: [UUID]? = nil) async throws {
        let beamRequest = BeamObjectRequest()

        let beamObjects = try await beamRequest.fetchAll(receivedAtAfter: lastReceivedAt, ids: ids)
        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        guard lastReceivedAt == nil || !beamObjects.isEmpty else {
            Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
            return
        }

        if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
            Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
            Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) beam objects fetched.",
                                   category: .beamObjectNetwork)
        }

        do {
            try self.parseFilteredObjects(self.filteredObjects(beamObjects))
            // Note: you don't need to save checksum here, they are saved in `translators[object.beamObjectType]` callback
            // called by `parseFilteredObjects`
            return
        } catch {
            let message = "Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support."
            Logger.shared.logError(message, category: .beamObject)
            if Configuration.env == .debug {
                AppDelegate.showMessage(message)
            }
            throw error
        }
    }
}

// MARK: - BeamObjectProtocol
extension BeamObjectManager {
    @discardableResult
    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try await saveToAPIClassic(objects, force: force, conflictPolicy: conflictPolicy)
            case .directUpload, nil: return try await saveToAPIWithDirectUpload(objects, force: force, conflictPolicy: conflictPolicy)
            }
        } else {
            return try await saveToAPIClassic(objects, force: force, conflictPolicy: conflictPolicy)
        }
    }

    func saveToAPIClassic<T: BeamObjectProtocol>(_ objects: [T],
                                                 force: Bool = false,
                                                 maxChunk: Int = 1000,
                                                 conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        guard !objects.isEmpty else {
            return []
        }

        // No need to split objects
        guard objects.count > maxChunk else {
            return try await saveToAPIClassicChunk(objects, force: force, conflictPolicy: conflictPolicy)
        }

        var index = maxChunk

        // API can't handle too many objects at once. If it fails we return early
        for objectsToSaveChunked in objects.chunked(into: maxChunk) {
            try Task.checkCancellation()

            Logger.shared.logDebug("Saving \(index)/\(objects.count)", category: .beamObjectNetwork)
            try await self.saveToAPIClassicChunk(objectsToSaveChunked, force: force, conflictPolicy: conflictPolicy)
            index += maxChunk
        }
        return objects
    }

    @discardableResult
    private func saveToAPIClassicChunk<T: BeamObjectProtocol>(_ objects: [T],
                                                              force: Bool = false,
                                                              conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        assert(objects.count <= 1000)

        var localTimer = Date()

        let beamObjects: [BeamObject] = try objects.map {
            try BeamObject(object: $0)
        }

        Logger.shared.logDebug("Converted \(objects.count) \(T.beamObjectType) to beam objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        localTimer = Date()

        let beamObjectsToSave = force ? beamObjects : updatedObjectsOnly(beamObjects)

        guard !beamObjectsToSave.isEmpty else {
            Logger.shared.logDebug("Skip \(beamObjects.count) objects, based on previousChecksum they were already saved",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return []
        }

        Logger.shared.logDebug("Filtered \(beamObjects.count) beam objects to \(beamObjectsToSave.count)",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        localTimer = Date()

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjectsToSave)
        beamObjectsToSave.forEach {
            $0.previousChecksum = checksums[$0]
        }

        if checksums.count != beamObjectsToSave.count {
            Logger.shared.logWarning("\(checksums.count) checksums doesn't match \(beamObjectsToSave.count) objects! It's ok if new.",
                                     category: .beamObjectChecksum)
        }

        Logger.shared.logDebug("Set \(checksums.count) checksums for \(beamObjectsToSave.count) objects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)

        Logger.shared.logDebug("Saving \(beamObjectsToSave.count) objects of type \(T.beamObjectType) on API",
                               category: .beamObjectNetwork)

        #if DEBUG
        let allObjectsSize = beamObjectsToSave.reduce(.zero) { ($1.data?.count ?? 0) + $0 }
        if allObjectsSize > 1024 * 1024 * 1024 {
            Logger.shared.logWarning("Total size is > \(allObjectsSize.byteSize), not efficient for multipart uploads",
                                     category: .beamObject)
        }
        #endif

        let request = BeamObjectRequest()

        do {
            try await request.save(beamObjectsToSave)
        } catch {
            try await saveToAPIFailure(objects, error, conflictPolicy: conflictPolicy)
        }
        do {
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjectsToSave)
            try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjectsToSave)
            return objects
        } catch {
            throw error
        }
    }

    fileprivate func uploadS3(beamObjectsUpload: [BeamObjectRequest.BeamObjectUpload], decoder: BeamJSONDecoder, objectsToSave: [BeamObject], chunkSize: Int, s3Upload: S3Transfer) async throws -> (Int, [Error]) {
        Logger.shared.logDebug("Upload using \(s3Upload.kind)", category: .beamObjectNetwork)
        var errors: [Error] = []
        var totalSize = 0
        let objectsById = objectsToSave.reduce(into: [:]) { $0[$1.id] = $1.data }
        try await withThrowingTaskGroup(of: Error?.self, body: { group in

            for i in 0..<beamObjectsUpload.count {

                let beamObjectUpload = beamObjectsUpload[i]
                let headers: [String: String] = try decoder.decode([String: String].self,
                                                                   from: beamObjectUpload.uploadHeaders.asData)
                guard let data = objectsById[beamObjectUpload.id] else {
                    Logger.shared.logError("Couldn't find data", category: .beamObjectNetwork)
                    assert(false)
                    continue
                }
                let op = s3Upload.makeOperation(uploadUrl: beamObjectUpload.uploadUrl, headers: headers, data: data)

                // After currentChunckSize async items, wait one to complete before adding the next on in order to keep max concurrent requests to ~chunkSize
                if i >= chunkSize {
                    do {
                        // For precise control (eg: tests) needs to happen before enqueing the next object
                        _ = try await group.next()
                    } catch {
                        errors.append(error)
                    }
                }

                totalSize += data.count
                group.addTask(operation: op)
            }

            if !group.isEmpty {
                // Finish waiting for the remaining async requests
                for try await error in group {
                    if let error = error {
                        errors.append(error)
                    }
                }
            }
        })

        return (totalSize, errors)
    }

    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ objects: [T],
                                                          force: Bool = false,
                                                          conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {

        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        guard !objects.isEmpty else {
            return []
        }

        var localTimer = Date()

        let beamObjects: [BeamObject] = try objects.map {
            try BeamObject(object: $0)
        }

        Logger.shared.logDebug("Converted \(objects.count) \(T.beamObjectType) to beam objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)
        localTimer = Date()

        let objectsToSave = force ? beamObjects : updatedObjectsOnly(beamObjects)

        guard !objectsToSave.isEmpty else {
            Logger.shared.logDebug("Skip \(beamObjects.count) objects, based on previousChecksum they were already saved",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return []
        }

        Logger.shared.logDebug("Filtered \(beamObjects.count) beam objects to \(objectsToSave.count)",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        let chunkSize = Configuration.env == .test ? 1 : 100
        localTimer = Date()

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: objectsToSave)
        for objectToSave in objectsToSave {
            objectToSave.previousChecksum = checksums[objectToSave]
            try objectToSave.encrypt()
        }

        if checksums.count != objectsToSave.count {
            Logger.shared.logWarning("\(checksums.count) checksums doesn't match \(objectsToSave.count) objects! It's ok if new.",
                                     category: .beamObjectChecksum)
        }

        Logger.shared.logDebug("Set \(checksums.count) checksums for \(objectsToSave.count) objects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)

        Logger.shared.logDebug("Saving \(objectsToSave.count) objects of type \(T.beamObjectType) on API",
                               category: .beamObjectNetwork)

        localTimer = Date()

        let request = BeamObjectRequest()

        let beamObjectsUpload: [BeamObjectRequest.BeamObjectUpload]
        do {
            beamObjectsUpload = try await request.prepare(objectsToSave)
        } catch {
            Logger.shared.logError("Saving \(objectsToSave.count) objects of type \(T.beamObjectType) on API: \(error.localizedDescription)",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            throw error
        }

        assert(beamObjectsUpload.count == objectsToSave.count)
        if beamObjectsUpload.count != objectsToSave.count {
            Logger.shared.logError("We don't get the same object counts", category: .beamObjectNetwork)
        }

        let decoder = BeamJSONDecoder()
        Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: starting",
                               category: .beamObjectNetwork)

        let  s3Upload: S3Transfer = S3TransferManager.shared

        localTimer = Date()
        let totalSize: Int, errors: [Error]
        (totalSize, errors) = try await uploadS3(beamObjectsUpload: beamObjectsUpload, decoder: decoder, objectsToSave: objectsToSave, chunkSize: chunkSize, s3Upload: s3Upload)

        Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: finished uploading \(totalSize.byteSize)",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        guard errors.isEmpty else {
            Logger.shared.logError(BeamObjectManagerError.multipleErrors(errors).localizedDescription,
                                   category: .beamObjectNetwork)
            throw BeamObjectManagerError.multipleErrors(errors)
        }
        let objectsById = beamObjectsUpload.reduce(into: [:]) { $0[$1.id] = $1.blobSignedId }
        // To not reupload data
        for objectToSave in objectsToSave {
            objectToSave.largeDataBlobId = objectsById[objectToSave.id]
            objectToSave.data = nil
        }

        let saveRequest = BeamObjectRequest()

        localTimer = Date()

        do {
            try await saveRequest.save(objectsToSave)
        } catch {
            Logger.shared.logError("Error while saving \(objectsToSave.count) \(T.beamObjectType)",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return try await self.saveToAPIFailure(objects, error, conflictPolicy: conflictPolicy)
        }
        try BeamObjectChecksum.savePreviousChecksums(beamObjects: objectsToSave)
        return objects
    }

    @discardableResult
    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                          _ error: Error,
                                                          conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            Logger.shared.logWarning("beamObjectInvalidChecksum -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                     category: .beamObject)
            return try await saveToAPIFailureBeamObjectInvalidChecksum(objects, error, conflictPolicy: conflictPolicy)
        case APIRequestError.apiErrors:
            Logger.shared.logWarning("APIRequestError.apiErrors -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                     category: .beamObject)
            return try await saveToAPIFailureApiErrors(objects, error, conflictPolicy: conflictPolicy)
        default:
            break
        }

        Logger.shared.logError("saveToAPIBeamObjectsFailure -- could not save \(objects.count) objects: \(error.localizedDescription)",
                               category: .beamObject)
        throw error
    }

    internal func saveToAPIFailureBeamObjectInvalidChecksum<T: BeamObjectProtocol>(_ objects: [T],
                                                                                   _ error: Error,
                                                                                   conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        // Note: we used to ask for `beamObjects` in the mutation when saving objects, in case we had issues and have remote objects.
        // However this means for rare errors, you're asking for remote objects. It also means the mutation on the server-side has to
        // manage returning objects in a fast way.

        // I removed that, but it means we need to find them manually now, which is what `extractGoodObjects` is doing.

        guard case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects) = error else {
            throw error
        }

        /*
         In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
         to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
         objects into `remoteObjects` to resend them back in the completion handler
         */

        // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
        guard var conflictedObject = objects.first(where: { $0.beamObjectId.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
            throw error
        }

        let goodObjects: [T] = extractGoodObjects(objects, conflictedObject)

        do {
            try BeamObjectChecksum.savePreviousChecksums(objects: goodObjects)

            var fetchedObject: T?
            do {
                fetchedObject = try await fetchObject(conflictedObject)
            } catch APIRequestError.notFound {
                try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
            }

            if let fetchedObject = fetchedObject {
                // Remote object was found, we store its checksum
                try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                conflictedObject = manageConflict(conflictedObject, fetchedObject)
            } else {
                // Object wasn't found, we delete checksum to resave with `nil` as previousChecksum
                try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
            }

            switch conflictPolicy {
            case .replace:
                _ = try await self.saveToAPI(conflictedObject, conflictPolicy: conflictPolicy)
                return goodObjects + [conflictedObject]
            case .fetchRemoteAndError:
                throw BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                      goodObjects,
                                                                      [fetchedObject].compactMap { $0 })
            }
        } catch {
            throw error
        }
    }

    /// Fetch remote objects
    /// `storePreviousChecksum` should be set to true when you fetch objects following-up a conflict, to ensure the next `save` API call includes the right
    /// `previousChecksum`
    @discardableResult
    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T],
                                             storePreviousChecksum: Bool = false) async throws -> [T] {
        let remoteBeamObjects = try await fetchBeamObjects(objects: objects)
        if storePreviousChecksum {
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: remoteBeamObjects)
        }
        return try self.beamObjectsToObjects(remoteBeamObjects)
    }

    /// Fetch all remote objects
    @discardableResult
    func fetchAllObjects<T: BeamObjectProtocol>(raisePrivateKeyError: Bool = false) async throws -> [T] {
        let remoteBeamObjects = try await fetchBeamObjects(T.beamObjectType.rawValue, raisePrivateKeyError: raisePrivateKeyError)
        return try self.beamObjectsToObjects(remoteBeamObjects)
    }

    internal func saveToAPIFailureApiErrors<T: BeamObjectProtocol>(_ objects: [T], _ error: Error, conflictPolicy: BeamObjectConflictResolution) async throws -> [T] {
        guard case APIRequestError.apiErrors(let errorable) = error,
              let remoteBeamObjects = (errorable as? BeamObjectRequest.UpdateBeamObjects)?.beamObjects,
              let errors = errorable.errors else {
            throw error
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

        try BeamObjectChecksum.savePreviousChecksums(objects: goodObjects)

        let fetchedConflictedObjects = try await fetchObjects(conflictedObjects, storePreviousChecksum: conflictPolicy == .replace)

        switch conflictPolicy {
        case .replace:

            // When we fetch objects but they have a different encryption key,
            // fetchedConflictedObjects will be empty and we don't know what to do with it since we can't
            // decode them or view their paste checksum for now
            // TODO: fetch remote object checksums and overwrite
            guard fetchedConflictedObjects.count == conflictedObjects.count else {
                Logger.shared.logError("Fetch error, fetched: \(fetchedConflictedObjects.count) instead of \(conflictedObjects.count)",
                                       category: .beamObjectNetwork)
                throw BeamObjectManagerError.fetchError
            }

            do {
                let toSaveObjects: [T] = try conflictedObjects.compactMap {
                    let conflictedObject = $0

                    let fetchedObject: T? = fetchedConflictedObjects.first(where: {
                        $0.beamObjectId == conflictedObject.beamObjectId
                    })

                    if let fetchedObject = fetchedObject {
                        return self.manageConflict(conflictedObject, fetchedObject)
                    }

                    // Object doesn't exist on the API side
                    try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                    return conflictedObject
                }

                try await self.saveToAPI(toSaveObjects, conflictPolicy: conflictPolicy)
                return goodObjects + toSaveObjects
            } catch {
                throw error
            }
        case .fetchRemoteAndError:
            throw BeamObjectManagerObjectError<T>.invalidChecksum(conflictedObjects,
                                                                  goodObjects,
                                                                  fetchedConflictedObjects)
        }
    }

    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        guard !disableSendingObjects || force else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }

        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try await saveToAPIClassic(object, force: force, conflictPolicy: conflictPolicy)
            case .directUpload, nil: return try await saveToAPIWithDirectUpload(object, force: force, conflictPolicy: conflictPolicy)
            }
        } else {
            return try await saveToAPIClassic(object, force: force, conflictPolicy: conflictPolicy)
        }
    }

    /// Completion will not be called if returned `APIRequest` is `nil`
    func saveToAPIClassic<T: BeamObjectProtocol>(_ object: T,
                                                 force: Bool = false,
                                                 conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let localTimer = Date()

        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            Logger.shared.logDebug("Skip object, based on previousChecksum it was already saved",
                                   category: .beamObjectNetwork)
            return object
        }

        let request = BeamObjectRequest()

        do {
            try await request.save(beamObject)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)

            Logger.shared.logDebug("Saved object",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return object
        } catch {
            return try await self.saveToAPIFailure(object, beamObject, error, conflictPolicy: conflictPolicy)
        }
    }

    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ object: T,
                                                          force: Bool = false,
                                                          conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let localTimer = Date()

        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            Logger.shared.logDebug("Skip object, based on previousChecksum it was already saved",
                                   category: .beamObjectNetwork)
            return object
        }

        let request = BeamObjectRequest()

        try beamObject.encrypt()

        guard let data = beamObject.data else { throw BeamObjectManagerError.noData }

        /*
         1st: we "prepare" our upload asking for a blobId and upload URL to our API
         */
        let beamObjectUpload = try await request.prepare(beamObject)
        let decoder = BeamJSONDecoder()
        let headers: [String: String] = try decoder.decode([String: String].self,
                                                           from: beamObjectUpload.uploadHeaders.asData)

        /*
         2nd: we direct upload the beam object data to the direct upload URL, including mandatory headers
         */
        try await request.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                  putHeaders: headers,
                                  data: data)

        beamObject.largeDataBlobId = beamObjectUpload.blobSignedId

        // Making sure we don't send data again to our API.
        beamObject.data = nil

        /*
         3rd: we let our API know we uploaded the data
         */
        do {
            try await request.save(beamObject)
        } catch {
            return try await self.saveToAPIFailure(object, beamObject, error, conflictPolicy: conflictPolicy)
        }
        do {
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            Logger.shared.logDebug("Saved object",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return object
        } catch {
            throw error
        }
    }

    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ object: T,
                                                          _ beamObject: BeamObject,
                                                          _ error: Error,
                                                          conflictPolicy: BeamObjectConflictResolution) async throws -> T {
        Logger.shared.logError("saveToAPIFailure: Could not save \(object): \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        // Early return except for checksum issues.
        guard case APIRequestError.beamObjectInvalidChecksum = error else {
            throw error
        }

        Logger.shared.logWarning("Invalid Checksum. Local previousChecksum: \(beamObject.previousChecksum ?? "-")",
                                 category: .beamObjectNetwork)

        do {
            let fetchedObject: T = try await fetchObject(object)
            let conflictedObject: T = try object.copy()

            switch conflictPolicy {
            case .replace:
                let newSaveObject = manageConflict(conflictedObject, fetchedObject)
                try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                return try await self.saveToAPI(newSaveObject, conflictPolicy: conflictPolicy)
            case .fetchRemoteAndError:
                try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                throw BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                                    [],
                                                                                    [fetchedObject].compactMap { $0 })
            }
        } catch APIRequestError.notFound {
            do {
                try BeamObjectChecksum.deletePreviousChecksum(object: object)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .beamObject)
            }
            throw error
        }
    }

    /// Fetch remote object
    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T) async throws -> T {
        let remoteBeamObject = try await fetchBeamObject(object: object)
        guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
            throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
        }

        do {
            let remoteObject: T = try remoteBeamObject.decodeBeamObject()
            return remoteObject
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObject)
            throw BeamObjectManagerError.decodingError(remoteBeamObject)
        }
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(_ object: T) async throws -> Date? {
        let remoteBeamObject: BeamObject = try await fetchMinimalBeamObject(object: object)
        // Check if you have the same IDs for 2 different object types
        guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
            throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
        }
        return remoteBeamObject.updatedAt
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(_ object: T) async throws -> String? {
        let remoteBeamObject: BeamObject = try await fetchMinimalBeamObject(object: object)
        // Check if you have the same IDs for 2 different object types
        guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
            throw BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")
        }
        return remoteBeamObject.dataChecksum
    }
}

// MARK: - BeamObject
extension BeamObjectManager {
    @discardableResult
    func saveToAPI(_ beamObjects: [BeamObject],
                   deep: Int = 0,
                   conflictPolicy: BeamObjectConflictResolution) async throws -> [BeamObject] {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

        beamObjects.forEach {
            $0.previousChecksum = checksums[$0]
        }

        let request = BeamObjectRequest()

        do {
            try await request.save(beamObjects)
        } catch {
            return try await self.saveToAPIBeamObjectsFailure(beamObjects, deep: deep, error, conflictPolicy: conflictPolicy)
        }

        try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjects)
        try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjects)

        return beamObjects
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              deep: Int = 0,
                                              _ error: Error,
                                              conflictPolicy: BeamObjectConflictResolution) async throws -> [BeamObject] {
        Logger.shared.logError("saveToAPIBeamObjectsFailure: Could not save \(beamObjects): \(error.localizedDescription)",
                               category: .beamObject)

        switch error {
        case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects):
            /*
             In such case we only had 1 error, but we sent multiple objects. The caller of this method will expect
             to get all objects back with sent checksum set (to save previousChecksum). We extract good returned
             objects into `remoteObjects` to resend them back in the completion handler
             */

            guard let updateBeamObjects = updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects else {
                throw error
            }

            // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                throw error
            }

            let goodObjects = beamObjects.filter {
                beamObject.id != $0.id
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: goodObjects)

            let mergedBeamObject = try await fetchAndReturnErrorBasedOnConflictPolicy(beamObject, conflictPolicy: conflictPolicy)
            _ = try await self.saveToAPI(mergedBeamObject, deep: deep + 1, conflictPolicy: conflictPolicy)
            return goodObjects + [mergedBeamObject]
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            return try await saveToAPIFailureAPIErrors(beamObjects, errors, conflictPolicy: conflictPolicy)
        default:
            break
        }
        throw error
    }

    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObject],
                                            deep: Int = 0,
                                            _ errors: [UserErrorData],
                                            conflictPolicy: BeamObjectConflictResolution) async throws -> [BeamObject] {

        let objectsInError: [BeamObject] = errors.compactMap { error in
            // Matching beamObject with the returned error. Could be faster with Set but this is rarelly called
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == error.objectid?.lowercased() }) else {
                return nil
            }

            // We only call `saveToAPIFailure` to fetch remote object with invalid checksum errors
            guard error.isErrorInvalidChecksum else { return nil }

            return beamObject
        }

        do {
            let newBeamObjects = try await fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: objectsInError, conflictPolicy: conflictPolicy)
            if conflictPolicy == .fetchRemoteAndError, !newBeamObjects.isEmpty {
                fatalError("When using fetchRemoteAndError conflict policy")
            }
            return try await self.saveToAPI(newBeamObjects, deep: deep + 1, conflictPolicy: conflictPolicy)
        } catch {
            if conflictPolicy == .replace {
                fatalError("When using replace conflict policy")
            }
            throw error
        }
    }

    func saveToAPI(_ beamObject: BeamObject, deep: Int = 0, conflictPolicy: BeamObjectConflictResolution) async throws -> BeamObject {
        guard !disableSendingObjects else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(beamObject: beamObject)

        let request = BeamObjectRequest()

        do {
            try await request.save(beamObject)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)
            return beamObject
        } catch {
            guard case APIRequestError.beamObjectInvalidChecksum = error else {
                Logger.shared.logError("saveToAPI Could not save \(beamObject): \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                throw error
            }

            Logger.shared.logWarning("Invalid Checksum. Local previous checksum: \(beamObject.previousChecksum ?? "-")",
                                     category: .beamObjectNetwork)

            let newBeamObject = try await self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject, conflictPolicy: conflictPolicy)
            Logger.shared.logWarning("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                     category: .beamObjectNetwork)
            Logger.shared.logWarning("Overwriting local object with remote checksum",
                                     category: .beamObjectNetwork)

            return try await self.saveToAPI(newBeamObject, deep: deep + 1, conflictPolicy: conflictPolicy)
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: [BeamObject], conflictPolicy: BeamObjectConflictResolution) async throws -> [BeamObject] {
        let remoteBeamObjects = try await fetchBeamObjects(beamObjects)
        do {
            switch conflictPolicy {
            case .replace:
                try BeamObjectChecksum.savePreviousChecksums(beamObjects: remoteBeamObjects)

                let newObjects: [BeamObject] = beamObjects.map { beamObject in
                    guard let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == beamObject.id }) else {
                        return beamObject
                    }

                    return self.manageConflict(beamObject, remoteBeamObject)
                }
                return newObjects
            case .fetchRemoteAndError:
                throw BeamObjectManagerError.multipleErrors(remoteBeamObjects.map {
                    BeamObjectManagerError.invalidChecksum($0)
                })
            }
        } catch {
            throw error
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject, conflictPolicy: BeamObjectConflictResolution) async throws -> BeamObject {

        do {
            let remoteBeamObject = try await fetchBeamObject(beamObject: beamObject)
            // This happened during tests, but could happen again if you have the same IDs for 2 different objects
            guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
               throw BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)
            }

            switch conflictPolicy {
            case .replace:
                try BeamObjectChecksum.savePreviousChecksum(beamObject: remoteBeamObject)

                let newBeamObject = self.manageConflict(beamObject, remoteBeamObject)
                return newBeamObject
            case .fetchRemoteAndError:
                throw BeamObjectManagerError.invalidChecksum(remoteBeamObject)
            }
        } catch {
            /*
             We tried fetching the remote beam object but it doesn't exist, we delete`previousChecksum`
             */
            if case APIRequestError.notFound = error {
                try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)

                switch conflictPolicy {
                case .replace:
                    return beamObject
                case .fetchRemoteAndError:
                    throw BeamObjectManagerError.invalidChecksum(beamObject)
                }
            }
            throw error
        }
    }

    internal func fetchBeamObjects<T: BeamObjectProtocol>(objects: [T]) async throws -> [BeamObject] {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            return try await request.fetchAllWithDataUrl(ids: objects.map { $0.beamObjectId },
                                                         beamObjectType: T.beamObjectType.rawValue)
        } else {
            return try await request.fetchAll(ids: objects.map { $0.beamObjectId },
                                              beamObjectType: T.beamObjectType.rawValue)
        }
    }

    internal func fetchBeamObjects(_ beamObjects: [BeamObject]) async throws -> [BeamObject] {
        let request = BeamObjectRequest()

        return try await request.fetchAll(ids: beamObjects.map { $0.id })
    }

    internal func fetchBeamObjects(_ ids: [UUID]) async throws -> [BeamObject] {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            return try await request.fetchAllWithDataUrl(ids: ids)
        } else {
            return try await request.fetchAll(ids: ids)
        }
    }

    internal func asyncFetchBeamObjectChecksums(_ ids: [UUID]) async throws -> [BeamObject] {
        let request = BeamObjectRequest()

        return try await request.fetchAll(ids: ids)
    }

    internal func fetchBeamObjects(_ beamObjectType: String,
                                   raisePrivateKeyError: Bool = false) async throws -> [BeamObject] {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            return try await request.fetchAllWithDataUrl(beamObjectType: beamObjectType, raisePrivateKeyError: raisePrivateKeyError)
        } else {
            return try await request.fetchAll(beamObjectType: beamObjectType, raisePrivateKeyError: raisePrivateKeyError)
        }
    }

    internal func fetchBeamObject(beamObject: BeamObject) async throws -> BeamObject {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            return try await request.fetchWithDataUrl(beamObject: beamObject)
        } else {
            return try await request.fetch(beamObject: beamObject)
        }
    }

    internal func fetchBeamObject<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            return try await request.fetchWithDataUrl(object: object)
        } else {
            return try await request.fetch(object: object)
        }
    }

    internal func fetchMinimalBeamObject(beamObject: BeamObject) async throws -> BeamObject {
        let request = BeamObjectRequest()

        return try await request.fetchMinimalBeamObject(beamObject: beamObject)
    }

    @discardableResult
    internal func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T) async throws -> BeamObject {
        let request = BeamObjectRequest()

        return try await request.fetchMinimalBeamObject(object: object)
    }

    @discardableResult
    func delete<T: BeamObjectProtocol>(object: T, raise404: Bool = false) async throws -> BeamObject? {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let request = BeamObjectRequest()

        return try await request.delete(object: object)
    }

    @discardableResult
    func delete(beamObject: BeamObject, raise404: Bool = false) async throws -> BeamObject? {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)
        let request = BeamObjectRequest()

        return try await request.delete(beamObject: beamObject)
    }

    @discardableResult
    func deleteAll(_ beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated else {
            throw BeamObjectManagerError.notAuthenticated
        }
        guard NetworkMonitor.isNetworkAvailable else {
            throw BeamObjectManagerError.networkUnavailable
        }

        let request = BeamObjectRequest()

        _ = try await request.deleteAll(beamObjectType: beamObjectType)

        if let beamObjectType = beamObjectType {
            try BeamObjectChecksum.deletePreviousChecksums(type: beamObjectType)
        } else {
            try BeamObjectChecksum.deleteAll()
        }
        return true
    }
}
