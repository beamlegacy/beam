import Foundation
import BeamCore
import Atomics

// swiftlint:disable file_length

extension BeamObjectManager {
    func syncAllFromAPI(force: Bool = false, delete: Bool = true, prepareBeforeSaveAll: (() -> Void)? = nil) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard Self.fullSyncRunning.load(ordering: .relaxed) == false else {
            throw BeamObjectManagerError.fullSyncAlreadyRunning
        }

        assert(Self.fullSyncRunning.load(ordering: .relaxed) == false)

        defer {
            // Reactivate sending object
            Self.disableSendingObjects = false

            Self.fullSyncRunning.store(false, ordering: .relaxed)
        }

        // swiftlint:disable:next date_init
        var localTimer = Date()

        Self.fullSyncRunning.store(true, ordering: .relaxed)

        if try await fetchAllByChecksumsFromAPI(force: force) == false {
            return false
        }

        do {
            if let prepareBeforeSaveAll = prepareBeforeSaveAll {
                Logger.shared.logDebug("syncAllFromAPI: calling prepareBeforeSaveAll",
                                       category: .beamObjectNetwork)
                prepareBeforeSaveAll()
            }

            // swiftlint:disable:next date_init
            localTimer = Date()
            Logger.shared.logDebug("syncAllFromAPI: calling saveAllToAPI",
                                   category: .beamObjectNetwork)
            let objectsCount = try self.saveAllToAPI(force: force)
            Logger.shared.logDebug("syncAllFromAPI: Called saveAllToAPI, saved \(objectsCount) objects",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)

            return true
        } catch {
            throw error
        }
    }

    // Will fetch remote checksums for objects since `lastReceivedAt` and then fetch objects for which we have a different
    // checksum locally, and therefor must be fetched from the API. This allows for a faster fetch since most of the time
    // we might already have those object locally if they had been sent and updated from the same device
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func fetchAllByChecksumsFromAPI(force: Bool = false) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamRequest = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(beamRequest)
        }
        #endif

        let lastReceivedAt: Date? = force ? nil : Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous lastReceivedAt for BeamObjects API call, skip checksums",
                                   category: .beamObjectNetwork)

            return try await self.fetchAllFromAPI()
        }

        // swiftlint:disable:next date_init
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
            return true
        }

        Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(beamObjects.count) beam object checksums fetched",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        do {
            // swiftlint:disable:next date_init
            localTimer = Date()
            let changedObjects = self.parseObjectChecksums(beamObjects)

            Logger.shared.logDebug("parsed \(beamObjects.count) checksums, got \(changedObjects.count) objects after",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)

            // swiftlint:disable:next date_init
            localTimer = Date()

            let ids: [UUID] = changedObjects.map { $0.id }

            guard !ids.isEmpty else {
                if let mostRecentReceivedAt = beamObjects.compactMap({ $0.receivedAt }).sorted().last {
                    Persistence.Sync.BeamObjects.last_received_at = mostRecentReceivedAt
                    Logger.shared.logDebug("new ReceivedAt: \(mostRecentReceivedAt.iso8601withFractionalSeconds). \(beamObjects.count) checksums",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)
                }
                return true
            }

            return try await self.fetchAllFromAPI(ids: ids)
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
    func fetchAllFromAPI() async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let lastReceivedAt: Date? = Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous updatedAt for BeamObjects API call",
                                   category: .beamObjectNetwork)
        }

        return try await fetchAllFromAPI(lastReceivedAt: lastReceivedAt)
    }

    private func fetchAllFromAPI(lastReceivedAt: Date? = nil,
                                 ids: [UUID]? = nil) async throws -> Bool {
        let beamRequest = BeamObjectRequest()

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(beamRequest)
        }
        #endif

        let beamObjects = try await beamRequest.fetchAll(receivedAtAfter: lastReceivedAt, ids: ids)
        // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
        // If not doing a delta sync, we don't as we want to update local document as `deleted`
        guard lastReceivedAt == nil || !beamObjects.isEmpty else {
            Logger.shared.logDebug("0 beam object fetched.", category: .beamObjectNetwork)
            return true
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
            return true
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
                                          requestUploadType: BeamObjectRequestUploadType? = nil) async throws -> [T] {
        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try await saveToAPIClassic(objects, force: force)
            case .directUpload, nil: return try await saveToAPIWithDirectUpload(objects, force: force)
            }
        } else {
            return try await saveToAPIClassic(objects, force: force)
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func saveToAPIClassic<T: BeamObjectProtocol>(_ objects: [T],
                                                 force: Bool = false,
                                                 maxChunk: Int = 1000) async throws -> [T] {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard !objects.isEmpty else {
            return []
        }

        // No need to split objects
        guard objects.count > maxChunk else {
            return try await saveToAPIClassicChunk(objects, force: force)
        }

        var index = maxChunk

        // API can't handle too many objects at once. If it fails we return early
        for objectsToSaveChunked in objects.chunked(into: maxChunk) {
            Logger.shared.logDebug("Saving \(index)/\(objects.count)", category: .beamObjectNetwork)
            try await self.saveToAPIClassicChunk(objectsToSaveChunked, force: force)
            index += maxChunk
        }
        return objects
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    @discardableResult
    private func saveToAPIClassicChunk<T: BeamObjectProtocol>(_ objects: [T],
                                                              force: Bool = false) async throws -> [T] {
        assert(objects.count <= 1000)

        // swiftlint:disable:next date_init
        var localTimer = Date()

        let beamObjects: [BeamObject] = try objects.map {
            try BeamObject(object: $0)
        }

        Logger.shared.logDebug("Converted \(objects.count) \(T.beamObjectType) to beam objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        // swiftlint:disable:next date_init
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

        // swiftlint:disable:next date_init
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
            try await saveToAPIFailure(objects, error)
        }
        do {
            try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjectsToSave)
            try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjectsToSave)
            return objects
        } catch {
            throw error
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ objects: [T],
                                                          force: Bool = false) async throws -> [T] {

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard !objects.isEmpty else {
            return []
        }

        // swiftlint:disable:next date_init
        var localTimer = Date()

        let beamObjects: [BeamObject] = try objects.map {
            try BeamObject(object: $0)
        }

        Logger.shared.logDebug("Converted \(objects.count) \(T.beamObjectType) to beam objects",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)
        // swiftlint:disable:next date_init
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

        // swiftlint:disable:next date_init
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

        // swiftlint:disable:next date_init
        localTimer = Date()

        var request = BeamObjectRequest()

        #if DEBUG
        if objectsToSave.count > 200 {
            Logger.shared.logWarning("Saving \(objectsToSave.count), which is probably too many to be efficient using direct uploads",
                                     category: .beamObject)
        }
        #endif

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
        var errors: [Error] = []

        Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: starting",
                               category: .beamObjectNetwork)

        // swiftlint:disable:next date_init
        localTimer = Date()
        var totalSize = 0

        for beamObjectsUploadChunk in beamObjectsUpload.chunked(into: 10) {
            for beamObjectUpload in beamObjectsUploadChunk {
                let headers: [String: String] = try decoder.decode([String: String].self,
                                                                   from: beamObjectUpload.uploadHeaders.asData)

                guard let data = objectsToSave.first(where: { $0.id == beamObjectUpload.id })?.data else {
                    assert(false)
                    Logger.shared.logError("Couldn't find data", category: .beamObjectNetwork)
                    continue
                }

                totalSize += data.count
                do {
                    try await request.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                                    putHeaders: headers,
                                                    data: data)
                } catch {
                    errors.append(error)
                }
            }
        }

        Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: finished uploading \(totalSize.byteSize)",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

        guard errors.isEmpty else {
            Logger.shared.logError(BeamObjectManagerError.multipleErrors(errors).localizedDescription,
                                   category: .beamObjectNetwork)
            throw BeamObjectManagerError.multipleErrors(errors)
        }

        // To not reupload data
        for objectToSave in objectsToSave {
            objectToSave.largeDataBlobId = beamObjectsUpload.first(where: { $0.id == objectToSave.id })?.blobSignedId
            objectToSave.data = nil
        }

        request = BeamObjectRequest()
        // swiftlint:disable:next date_init
        localTimer = Date()

        do {
            try await request.save(objectsToSave)
        } catch {
            Logger.shared.logError("Error while saving \(objectsToSave.count) \(T.beamObjectType)",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return try await self.saveToAPIFailure(objects, error)
        }
        try BeamObjectChecksum.savePreviousChecksums(beamObjects: objectsToSave)
        return objects
    }

    @discardableResult
    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ objects: [T],
                                                          _ error: Error) async throws -> [T] {

        switch error {
        case APIRequestError.beamObjectInvalidChecksum:
            Logger.shared.logWarning("beamObjectInvalidChecksum -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                     category: .beamObject)
            return try await saveToAPIFailureBeamObjectInvalidChecksum(objects, error)
        case APIRequestError.apiErrors:
            Logger.shared.logWarning("APIRequestError.apiErrors -- could not save \(objects.count) objects: \(error.localizedDescription)",
                                     category: .beamObject)
            return try await saveToAPIFailureApiErrors(objects, error)
        default:
            break
        }

        Logger.shared.logError("saveToAPIBeamObjectsFailure -- could not save \(objects.count) objects: \(error.localizedDescription)",
                               category: .beamObject)
        throw error
    }

    internal func saveToAPIFailureBeamObjectInvalidChecksum<T: BeamObjectProtocol>(_ objects: [T],
                                                                                   _ error: Error) async throws -> [T] {
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

            switch self.conflictPolicyForSave {
            case .replace:
                if let fetchedObject = fetchedObject {
                    // Remote object was found, we store its checksum
                    try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                    conflictedObject = manageConflict(conflictedObject, fetchedObject)
                } else {
                    // Object wasn't found, we delete checksum to resave with `nil` as previousChecksum
                    try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                }

                _ = try await self.saveToAPI(conflictedObject)
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func saveToAPIFailureApiErrors<T: BeamObjectProtocol>(_ objects: [T], _ error: Error) async throws -> [T] {
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

        let fetchedConflictedObjects = try await fetchObjects(conflictedObjects, storePreviousChecksum: conflictPolicyForSave == .replace)

        switch self.conflictPolicyForSave {
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

                try await self.saveToAPI(toSaveObjects)
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
                                          requestUploadType: BeamObjectRequestUploadType? = nil) async throws -> T {
        guard !Self.disableSendingObjects || force else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }

        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try await saveToAPIClassic(object, force: force)
            case .directUpload, nil: return try await saveToAPIWithDirectUpload(object, force: force)
            }
        } else {
            return try await saveToAPIClassic(object, force: force)
        }
    }

    /// Completion will not be called if returned `APIRequest` is `nil`
    func saveToAPIClassic<T: BeamObjectProtocol>(_ object: T,
                                                 force: Bool = false) async throws -> T {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        // swiftlint:disable:next date_init
        let localTimer = Date()

        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            Logger.shared.logDebug("Skip object, based on previousChecksum it was already saved",
                                   category: .beamObjectNetwork)
            return object
        }

        let request = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        do {
            try await request.save(beamObject)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)

            Logger.shared.logDebug("Saved object",
                                   category: .beamObjectNetwork,
                                   localTimer: localTimer)
            return object
        } catch {
            return try await self.saveToAPIFailure(object, beamObject, error)
        }
    }

    // swiftlint:disable:next function_body_length
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ object: T,
                                                          force: Bool = false) async throws -> T {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        // swiftlint:disable:next date_init
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
            return try await self.saveToAPIFailure(object, beamObject, error)
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
                                                          _ error: Error) async throws -> T {
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

            switch self.conflictPolicyForSave {
            case .replace:
                let newSaveObject = manageConflict(conflictedObject, fetchedObject)
                try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                return try await self.saveToAPI(newSaveObject)
            case .fetchRemoteAndError:
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
                   deep: Int = 0) async throws -> [BeamObject] {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

        beamObjects.forEach {
            $0.previousChecksum = checksums[$0]
        }

        let request = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        do {
            try await request.save(beamObjects)
        } catch {
            return try await self.saveToAPIBeamObjectsFailure(beamObjects, deep: deep, error)
        }

        try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjects)
        try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjects)

        return beamObjects
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              deep: Int = 0,
                                              _ error: Error) async throws -> [BeamObject] {
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

            let mergedBeamObject = try await fetchAndReturnErrorBasedOnConflictPolicy(beamObject)
            _ = try await self.saveToAPI(mergedBeamObject, deep: deep + 1)
            return goodObjects + [mergedBeamObject]
        case APIRequestError.apiErrors(let errorable):
            guard let errors = errorable.errors else { break }

            Logger.shared.logError("\(errorable)", category: .beamObject)
            return try await saveToAPIFailureAPIErrors(beamObjects, errors)
        default:
            break
        }
        throw error
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIFailureAPIErrors(_ beamObjects: [BeamObject],
                                            deep: Int = 0,
                                            _ errors: [UserErrorData]) async throws -> [BeamObject] {

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
            let newBeamObjects = try await fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: objectsInError)
            if self.conflictPolicyForSave == .fetchRemoteAndError, !newBeamObjects.isEmpty {
                fatalError("When using fetchRemoteAndError conflict policy")
            }
            return try await self.saveToAPI(newBeamObjects, deep: deep + 1)
        } catch {
            if self.conflictPolicyForSave == .replace {
                fatalError("When using replace conflict policy")
            }
            throw error
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func saveToAPI(_ beamObject: BeamObject,
                   deep: Int = 0) async throws -> BeamObject {
        guard !Self.disableSendingObjects else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard deep < 3 else {
            throw BeamObjectManagerError.nestedTooDeep
        }

        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(beamObject: beamObject)

        let request = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

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

            let newBeamObject = try await self.fetchAndReturnErrorBasedOnConflictPolicy(beamObject)
            Logger.shared.logWarning("Remote object checksum: \(newBeamObject.dataChecksum ?? "-")",
                                     category: .beamObjectNetwork)
            Logger.shared.logWarning("Overwriting local object with remote checksum",
                                     category: .beamObjectNetwork)

            return try await self.saveToAPI(newBeamObject, deep: deep + 1)
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: [BeamObject]) async throws -> [BeamObject] {
        let remoteBeamObjects = try await fetchBeamObjects(beamObjects)
        do {
            switch self.conflictPolicyForSave {
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
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject) async throws -> BeamObject {

        do {
            let remoteBeamObject = try await fetchBeamObject(beamObject: beamObject)
            // This happened during tests, but could happen again if you have the same IDs for 2 different objects
            guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
               throw BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)
            }

            switch self.conflictPolicyForSave {
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

                switch self.conflictPolicyForSave {
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
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return try await request.delete(object: object)
    }

    @discardableResult
    func delete(beamObject: BeamObject, raise404: Bool = false) async throws -> BeamObject? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)
        let request = BeamObjectRequest()
        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return try await request.delete(beamObject: beamObject)
    }

    @discardableResult
    func deleteAll(_ beamObjectType: BeamObjectObjectType? = nil) async throws -> Bool {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        _ = try await request.deleteAll(beamObjectType: beamObjectType)

        if let beamObjectType = beamObjectType {
            try BeamObjectChecksum.deletePreviousChecksums(type: beamObjectType)
        } else {
            try BeamObjectChecksum.deleteAll()
        }
        return true
    }
}
