import Foundation
import BeamCore

// swiftlint:disable file_length

extension BeamObjectManager {
    func syncAllFromAPI(force: Bool = false, delete: Bool = true, prepareBeforeSaveAll: (() -> Void)? = nil, _ completion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        var localTimer = Date()

        try fetchAllByChecksumsFromAPI(force: force) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logDebug("syncAllFromAPI: \(error.localizedDescription)",
                                       category: .beamObjectNetwork,
                                       localTimer: localTimer)
                completion?(result)
            case .success:
                Logger.shared.logDebug("syncAllFromAPI: called fetchAllByChecksumsFromAPI",
                                       category: .beamObjectNetwork,
                                       localTimer: localTimer)

                do {
                    if let prepareBeforeSaveAll = prepareBeforeSaveAll {
                        Logger.shared.logDebug("syncAllFromAPI: calling prepareBeforeSaveAll",
                                               category: .beamObjectNetwork)
                        prepareBeforeSaveAll()
                    }

                    localTimer = Date()
                    Logger.shared.logDebug("syncAllFromAPI: calling saveAllToAPI",
                                           category: .beamObjectNetwork)
                    let objectsCount = try self.saveAllToAPI(force: force)
                    Logger.shared.logDebug("syncAllFromAPI: Called saveAllToAPI, saved \(objectsCount) objects",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)

                    completion?(.success(true))
                } catch {
                    completion?(.failure(error))
                }

                // Reactivate sending object
                Self.disableSendingObjects = false
            }
        }
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    func saveAllToAPI(force: Bool = false) throws -> Int {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)
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

        for (_, manager) in Self.managerInstances {
            group.enter()

            // Note: I tried QOS `userInitiated` but I had 50sec latency... `userInteractive` makes it instant.
            DispatchQueue.global(qos: .userInteractive).async {
                let localTimer = Date()

                do {
                    Logger.shared.logDebug("saveAllToAPI using \(manager)",
                                           category: .beamObjectNetwork)

                    let request = try manager.saveAllOnBeamObjectApi(force: force) { result in
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
                        DispatchQueue.main.async {
                            Self.networkRequests.append(request)
                        }
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
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func fetchAllByChecksumsFromAPI(force: Bool = false, _ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let beamRequest = BeamObjectRequest()

        let lastReceivedAt: Date? = force ? nil : Persistence.Sync.BeamObjects.last_received_at

        if let lastReceivedAt = lastReceivedAt {
            Logger.shared.logDebug("Using lastReceivedAt for BeamObjects API call: \(lastReceivedAt.iso8601withFractionalSeconds)",
                                   category: .beamObjectNetwork)
        } else {
            Logger.shared.logDebug("No previous lastReceivedAt for BeamObjects API call, skip checksums",
                                   category: .beamObjectNetwork)

            try self.fetchAllFromAPI(completion)
            return
        }

        var localTimer = Date()

        try beamRequest.fetchAllChecksums(receivedAtAfter: lastReceivedAt,
                                          skipDeleted: Persistence.Sync.BeamObjects.last_received_at == nil) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(error.localizedDescription)",
                                       category: .beamObjectNetwork)
                completion(.failure(error))
            case .success(let beamObjects):
                // If we are doing a delta refreshAll, and 0 document is fetched, we exit early
                // If not doing a delta sync, we don't as we want to update local document as `deleted`
                guard lastReceivedAt == nil || !beamObjects.isEmpty else {
                    Logger.shared.logDebug("fetchAllByChecksumsFromAPI: 0 beam object checksums fetched",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)
                    completion(.success(true))
                    return
                }

                Logger.shared.logDebug("fetchAllByChecksumsFromAPI: \(beamObjects.count) beam object checksums fetched",
                                       category: .beamObjectNetwork,
                                       localTimer: localTimer)

                do {
                    localTimer = Date()
                    let changedObjects = self.parseObjectChecksums(beamObjects)

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
                        completion(.success(true))
                        return
                    }

                    try self.fetchAllFromAPI(ids: ids, completion)
                } catch {
                    let message = "Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support."
                    Logger.shared.logError(message, category: .beamObject)
                    if Configuration.env == .debug {
                        AppDelegate.showMessage(message)
                    }
                    completion(.failure(error))
                }
            }
        }

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(beamRequest)
        }
        #endif
    }

    /// Will fetch all updates from the API and call each managers based on object's type
    func fetchAllFromAPI(_ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
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

        try fetchAllFromAPI(lastReceivedAt: lastReceivedAt, completion)
    }

    private func fetchAllFromAPI(lastReceivedAt: Date? = nil,
                                 ids: [UUID]? = nil,
                                 _ completion: @escaping ((Result<Bool, Error>) -> Void)) throws {
        let beamRequest = BeamObjectRequest()
        try beamRequest.fetchAll(receivedAtAfter: lastReceivedAt, ids: ids) { result in
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
                    // Note: you don't need to save checksum here, they are saved in `translators[object.beamObjectType]` callback
                    // called by `parseFilteredObjects`
                    completion(.success(true))
                    return
                } catch {
                    let message = "Error fetching objects from API: \(error.localizedDescription). This is not normal, check the logs and ask support."
                    Logger.shared.logError(message, category: .beamObject)
                    if Configuration.env == .debug {
                        AppDelegate.showMessage(message)
                    }
                    completion(.failure(error))
                }
            }
        }

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(beamRequest)
        }
        #endif
    }
}

// MARK: - BeamObjectProtocol
extension BeamObjectManager {
    func updatedObjectsOnly(_ beamObjects: [BeamObject]) -> [BeamObject] {
        let checksums = BeamObjectChecksum.previousChecksums(beamObjects: beamObjects)

        return beamObjects.filter {
            checksums[$0] != $0.dataChecksum || checksums[$0] == nil
        }
    }

    func saveToAPI<T: BeamObjectProtocol>(_ objects: [T],
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          _ completion: @escaping ((Result<[T], Error>) -> Void)) throws -> APIRequest? {
        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try saveToAPIClassic(objects, force: force, completion)
            case .directUpload, nil: return try saveToAPIWithDirectUpload(objects, force: force, completion)
            }
        } else {
            return try saveToAPIClassic(objects, force: force, completion)
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func saveToAPIClassic<T: BeamObjectProtocol>(_ objects: [T],
                                                 force: Bool = false,
                                                 _ completion: @escaping ((Result<[T], Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard !objects.isEmpty else {
            completion(.success([]))
            return nil
        }

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
            completion(.success([]))
            return nil
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

        var errorCompletionCalled = false

        // API can't handle too many objects at once. If it fails we return early
        for beamObjectsToSaveChunked in beamObjectsToSave.chunked(into: 1000) {
            let request = BeamObjectRequest()

            if beamObjectsToSave.count > 1000 {
                Logger.shared.logDebug("About to save \(beamObjectsToSaveChunked.count) objects",
                                       category: .beamObjectNetwork)
            }

            let semaphore = DispatchSemaphore(value: 0)

            try request.save(beamObjectsToSaveChunked) { result in
                switch result {
                case .failure(let error):
                    // Note: we only pass to saveToAPIFailure the objects we tried saving
                    let beamObjectsToSaveChunkedIds = beamObjectsToSaveChunked.map { $0.id }
                    let objectsToSaveChunked = objects.filter {
                        beamObjectsToSaveChunkedIds.contains($0.beamObjectId)
                    }
                    self.saveToAPIFailure(objectsToSaveChunked, error, completion)
                    errorCompletionCalled = true
                case .success:
                    do {
                        try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjectsToSaveChunked)
                        try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjectsToSaveChunked)
                    } catch {
                        completion(.failure(error))
                        errorCompletionCalled = true
                    }
                }

                semaphore.signal()
            }

            semaphore.wait()

            if errorCompletionCalled { break }
        }

        if errorCompletionCalled == false {
            completion(.success(objects))
        }

        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity
    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ objects: [T],
                                                          force: Bool = false,
                                                          _ completion: @escaping ((Result<[T], Error>) -> Void)) throws -> APIRequest? {

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        guard !objects.isEmpty else {
            completion(.success([]))
            return nil
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
            completion(.success([]))
            return nil
        }

        Logger.shared.logDebug("Filtered \(beamObjects.count) beam objects to \(objectsToSave.count)",
                               category: .beamObjectNetwork,
                               localTimer: localTimer)

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

        #if DEBUG
        if objectsToSave.count > 200 {
            Logger.shared.logWarning("Saving \(objectsToSave.count), which is probably too many to be efficient using direct uploads",
                                     category: .beamObject)
        }
        #endif

        try request.prepare(objectsToSave) { requestResult in
            switch requestResult {
            case .failure(let error):
                Logger.shared.logError("Saving \(objectsToSave.count) objects of type \(T.beamObjectType) on API: \(error.localizedDescription)",
                                       category: .beamObjectNetwork,
                                       localTimer: localTimer)
                completion(.failure(error))
            case .success(let beamObjectsUpload):
                do {
                    assert(beamObjectsUpload.count == objectsToSave.count)
                    if beamObjectsUpload.count != objectsToSave.count {
                        Logger.shared.logError("We don't get the same object counts", category: .beamObjectNetwork)
                    }

                    let decoder = JSONDecoder()
                    var errors: [Error] = []
                    let lock = DispatchSemaphore(value: 1)

                    Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: starting",
                                           category: .beamObjectNetwork)

                    localTimer = Date()
                    var totalSize = 0

                    // TODO: limit parallelization?
                    for beamObjectsUploadChunk in beamObjectsUpload.chunked(into: 10) {
                        let group = DispatchGroup()
                        for beamObjectUpload in beamObjectsUploadChunk {
                            let headers: [String: String] = try decoder.decode([String: String].self,
                                                                               from: beamObjectUpload.uploadHeaders.asData)

                            guard let data = objectsToSave.first(where: { $0.id == beamObjectUpload.id })?.data else {
                                assert(false)
                                Logger.shared.logError("Couldn't find data", category: .beamObjectNetwork)
                                continue
                            }

                            totalSize += data.count
                            group.enter()
                            try request.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                                      putHeaders: headers,
                                                      data: data) { result in
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
                    }

                    Logger.shared.logDebug("\(objectsToSave.count) \(T.beamObjectType) direct uploads: finished uploading \(totalSize.byteSize)",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)

                    guard errors.isEmpty else {
                        Logger.shared.logError(BeamObjectManagerError.multipleErrors(errors).localizedDescription,
                                               category: .beamObjectNetwork)
                        completion(.failure(BeamObjectManagerError.multipleErrors(errors)))
                        return
                    }

                    // To not reupload data
                    for objectToSave in objectsToSave {
                        objectToSave.largeDataBlobId = beamObjectsUpload.first(where: { $0.id == objectToSave.id })?.blobSignedId
                        objectToSave.data = nil
                    }

                    let request = BeamObjectRequest()
                    localTimer = Date()

                    try request.save(objectsToSave) { result in
                        switch result {
                        case .failure(let error):
                            Logger.shared.logError("Error while saving \(objectsToSave.count) \(T.beamObjectType)",
                                                   category: .beamObjectNetwork,
                                                   localTimer: localTimer)
                            self.saveToAPIFailure(objects, error, completion)
                        case .success:
                            do {
                                try BeamObjectChecksum.savePreviousChecksums(beamObjects: objectsToSave)
                                completion(.success(objects))
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
        // Note: we used to ask for `beamObjects` in the mutation when saving objects, in case we had issues and have remote objects.
        // However this means for rare errors, you're asking for remote objects. It also means the mutation on the server-side has to
        // manage returning objects in a fast way.

        // I removed that, but it means we need to find them manually now, which is what `extractGoodObjects` is doing.

        guard case APIRequestError.beamObjectInvalidChecksum(let updateBeamObjects) = error else {
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

        let goodObjects: [T] = extractGoodObjects(objects, conflictedObject)

        do {
            try BeamObjectChecksum.savePreviousChecksums(objects: goodObjects)

            var fetchedObject: T?
            do {
                fetchedObject = try fetchObject(conflictedObject)
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

                _ = try self.saveToAPI(conflictedObject) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success: completion(.success(goodObjects + [conflictedObject]))
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
    /// `storePreviousChecksum` should be set to true when you fetch objects following-up a conflict, to ensure the next `save` API call includes the right
    /// `previousChecksum`
    @discardableResult
    func fetchObjects<T: BeamObjectProtocol>(_ objects: [T],
                                             storePreviousChecksum: Bool = false,
                                             _ completion: @escaping (Result<[T], Error>) -> Void) throws -> APIRequest {
        try fetchBeamObjects(objects: objects) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObjects):
                do {
                    if storePreviousChecksum {
                        try BeamObjectChecksum.savePreviousChecksums(beamObjects: remoteBeamObjects)
                    }
                    completion(.success(try self.beamObjectsToObjects(remoteBeamObjects)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Fetch all remote objects
    @discardableResult
    func fetchAllObjects<T: BeamObjectProtocol>(raisePrivateKeyError: Bool = false, _ completion: @escaping (Result<[T], Error>) -> Void) throws -> APIRequest {
        try fetchBeamObjects(T.beamObjectType.rawValue, raisePrivateKeyError: raisePrivateKeyError) { fetchResult in
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

        let goodObjects: [T] = extractGoodObjects(objects, objectErrorIds, remoteBeamObjects)

        do {
            try BeamObjectChecksum.savePreviousChecksums(objects: goodObjects)

            try fetchObjects(conflictedObjects, storePreviousChecksum: conflictPolicyForSave == .replace) { result in
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
                            Logger.shared.logError("Fetch error, fetched: \(fetchedConflictedObjects.count) instead of \(conflictedObjects.count)",
                                                   category: .beamObjectNetwork)
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
                                }

                                // Object doesn't exist on the API side
                                try BeamObjectChecksum.deletePreviousChecksum(object: conflictedObject)
                                return conflictedObject
                            }

                            _ = try self.saveToAPI(toSaveObjects) { result in
                                switch result {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success:
                                    completion(.success(goodObjects + toSaveObjects))
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

    func saveToAPI<T: BeamObjectProtocol>(_ object: T,
                                          force: Bool = false,
                                          requestUploadType: BeamObjectRequestUploadType? = nil,
                                          _ completion: @escaping ((Result<T, Error>) -> Void)) throws -> APIRequest? {
        guard !Self.disableSendingObjects || force else {
            throw BeamObjectManagerError.sendingObjectsDisabled
        }

        if Configuration.beamObjectDataUploadOnSeparateCall {
            switch requestUploadType {
            case .multipartUpload: return try saveToAPIClassic(object, force: force, completion)
            case .directUpload, nil: return try saveToAPIWithDirectUpload(object, force: force, completion)
            }
        } else {
            return try saveToAPIClassic(object, force: force, completion)
        }
    }

    /// Completion will not be called if returned `APIRequest` is `nil`
    func saveToAPIClassic<T: BeamObjectProtocol>(_ object: T,
                                                 force: Bool = false,
                                                 _ completion: @escaping ((Result<T, Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let localTimer = Date()

        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            Logger.shared.logDebug("Skip object, based on previousChecksum it was already saved",
                                   category: .beamObjectNetwork)
            completion(.success(object))
            return nil
        }

        let request = BeamObjectRequest()

        try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success:
                // Note: we can't decode the remote `BeamObject` as that would require to fetch all details back from
                // the API when saving (it needs `data`). Instead we use the objects passed within the method attribute,
                // and set their `previousChecksum`

                do {
                    try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
                    try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)

                    Logger.shared.logDebug("Saved object",
                                           category: .beamObjectNetwork,
                                           localTimer: localTimer)
                    completion(.success(object))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                self.saveToAPIFailure(object, beamObject, error, completion)
            }
        }

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }

    // swiftlint:disable:next function_body_length
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func saveToAPIWithDirectUpload<T: BeamObjectProtocol>(_ object: T,
                                                          force: Bool = false,
                                                          _ completion: @escaping ((Result<T, Error>) -> Void)) throws -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let localTimer = Date()

        let beamObject = try BeamObject(object: object)
        beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

        guard beamObject.previousChecksum != beamObject.dataChecksum || beamObject.previousChecksum == nil || force else {
            Logger.shared.logDebug("Skip object, based on previousChecksum it was already saved",
                                   category: .beamObjectNetwork)
            completion(.success(object))
            return nil
        }

        let request = BeamObjectRequest()

        try beamObject.encrypt()

        guard let data = beamObject.data else { throw BeamObjectManagerError.noData }

        /*
         1st: we "prepare" our upload asking for a blobId and upload URL to our API
         */
        try request.prepare(beamObject, { requestResult in
            switch requestResult {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                completion(.failure(error))
            case .success(let beamObjectUpload):
                do {
                    let decoder = JSONDecoder()
                    let headers: [String: String] = try decoder.decode([String: String].self,
                                                                       from: beamObjectUpload.uploadHeaders.asData)

                    /*
                     2nd: we direct upload the beam object data to the direct upload URL, including mandatory headers
                     */
                    try request.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                              putHeaders: headers,
                                              data: data) { result in

                        switch result {
                        case .failure(let error):
                            Logger.shared.logError(error.localizedDescription, category: .beamObjectNetwork)
                            completion(.failure(error))
                        case .success:
                            do {
                                let request = BeamObjectRequest()

                                beamObject.largeDataBlobId = beamObjectUpload.blobSignedId

                                // Making sure we don't send data again to our API.
                                beamObject.data = nil

                                /*
                                 3rd: we let our API know we uploaded the data
                                 */
                                try request.save(beamObject) { result in
                                    switch result {
                                    case .failure(let error):
                                        self.saveToAPIFailure(object, beamObject, error, completion)
                                    case .success:
                                        do {
                                            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
                                            Logger.shared.logDebug("Saved object",
                                                                   category: .beamObjectNetwork,
                                                                   localTimer: localTimer)
                                            completion(.success(object))
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
                } catch {
                    completion(.failure(error))
                }
            }
        })

        return request
    }

    internal func saveToAPIFailure<T: BeamObjectProtocol>(_ object: T,
                                                          _ beamObject: BeamObject,
                                                          _ error: Error,
                                                          _ completion: @escaping ((Result<T, Error>) -> Void)) {
        Logger.shared.logError("saveToAPIFailure: Could not save \(object): \(error.localizedDescription)",
                               category: .beamObjectNetwork)

        // Early return except for checksum issues.
        guard case APIRequestError.beamObjectInvalidChecksum = error else {
            completion(.failure(error))
            return
        }

        Logger.shared.logWarning("Invalid Checksum. Local previousChecksum: \(beamObject.previousChecksum ?? "-")",
                                 category: .beamObjectNetwork)

        do {
            let fetchedObject: T = try fetchObject(object)
            let conflictedObject: T = try object.copy()

            switch self.conflictPolicyForSave {
            case .replace:
                let newSaveObject = manageConflict(conflictedObject, fetchedObject)

                try BeamObjectChecksum.savePreviousChecksum(object: fetchedObject)
                _ = try self.saveToAPI(newSaveObject, completion)
            case .fetchRemoteAndError:
                completion(.failure(BeamObjectManagerObjectError<T>.invalidChecksum([conflictedObject],
                                                                                    [],
                                                                                    [fetchedObject].compactMap { $0 })))
            }
        } catch APIRequestError.notFound {
            do {
                try BeamObjectChecksum.deletePreviousChecksum(object: object)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .beamObject)
            }

            completion(.failure(error))
        } catch {
            completion(.failure(error))
        }
    }

    /// Fetch remote object
    @discardableResult
    func fetchObject<T: BeamObjectProtocol>(_ object: T,
                                            _ completion: @escaping (Result<T, Error>) -> Void) throws -> APIRequest {
        try fetchBeamObject(object: object) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")))
                    return
                }

                do {
                    let remoteObject: T = try remoteBeamObject.decodeBeamObject()
                    completion(.success(remoteObject))
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .beamObject)
                    completion(.failure(BeamObjectManagerError.decodingError(remoteBeamObject)))
                }
            }
        }
    }

    func fetchObjectUpdatedAt<T: BeamObjectProtocol>(_ object: T,
                                                     _ completion: @escaping (Result<Date?, Error>) -> Void) throws -> APIRequest {
        try fetchMinimalBeamObject(object: object) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")))
                    return
                }

                completion(.success(remoteBeamObject.updatedAt))
            }
        }
    }

    func fetchObjectChecksum<T: BeamObjectProtocol>(_ object: T,
                                                    _ completion: @escaping (Result<String?, Error>) -> Void) throws -> APIRequest {
        try fetchMinimalBeamObject(object: object) { fetchResult in
            switch fetchResult {
            case .failure(let error): completion(.failure(error))
            case .success(let remoteBeamObject):
                // Check if you have the same IDs for 2 different object types
                guard remoteBeamObject.beamObjectType == T.beamObjectType.rawValue else {
                    completion(.failure(BeamObjectManagerDelegateError.runtimeError("returned object \(remoteBeamObject) is not a \(T.beamObjectType)")))
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
                   deep: Int = 0,
                   _ completion: @escaping ((Result<[BeamObject], Error>) -> Void)) throws -> APIRequest {
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

        try request.save(beamObjects) { result in
            switch result {
            case .failure(let error):
                self.saveToAPIBeamObjectsFailure(beamObjects, deep: deep, error, completion)
            case .success:
                do {
                    try BeamObjectChecksum.savePreviousChecksums(beamObjects: beamObjects)
                    try BeamObjectChecksum.savePreviousObjects(beamObjects: beamObjects)
                    completion(.success(beamObjects))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }

    /// Will look at each errors, and fetch remote object to include it in the completion if it was a checksum error
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal func saveToAPIBeamObjectsFailure(_ beamObjects: [BeamObject],
                                              deep: Int = 0,
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

            guard let updateBeamObjects = updateBeamObjects as? BeamObjectRequest.UpdateBeamObjects else {
                completion(.failure(error))
                return
            }

            // APIRequestError.beamObjectInvalidChecksum happens when only 1 object is in error, if not something is bogus
            guard let beamObject = beamObjects.first(where: { $0.id.uuidString.lowercased() == updateBeamObjects.errors?.first?.objectid?.lowercased()}) else {
                completion(.failure(error))
                return
            }

            let goodObjects = beamObjects.filter {
                beamObject.id != $0.id
            }

            // APIRequestError.beamObjectInvalidChecksum is only raised when having 1 object
            // We can just return the error after fetching the object
            do {
                try BeamObjectChecksum.savePreviousChecksums(beamObjects: goodObjects)

                try fetchAndReturnErrorBasedOnConflictPolicy(beamObject) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let mergedBeamObject):
                        do {
                            _ = try self.saveToAPI(mergedBeamObject, deep: deep + 1) { result in
                                switch result {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success:
                                    completion(.success(goodObjects + [mergedBeamObject]))
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
                                            deep: Int = 0,
                                            _ errors: [UserErrorData],
                                            _ completion: @escaping ((Result<[BeamObject], Error>) -> Void)) {

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
            try fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: objectsInError) { result in
                switch result {
                case .failure(let resultErrors):
                    if self.conflictPolicyForSave == .replace {
                        fatalError("When using replace conflict policy")
                    }

                    completion(.failure(resultErrors))
                case .success(let newBeamObjects):
                    if self.conflictPolicyForSave == .fetchRemoteAndError, !newBeamObjects.isEmpty {
                        fatalError("When using fetchRemoteAndError conflict policy")
                    }

                    do {
                        _ = try self.saveToAPI(newBeamObjects, deep: deep + 1, completion)
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func saveToAPI(_ beamObject: BeamObject,
                   deep: Int = 0,
                   _ completion: @escaping ((Result<BeamObject, Error>) -> Void)) throws -> APIRequest {
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

        try request.save(beamObject) { requestResult in
            switch requestResult {
            case .success:
                do {
                    try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
                    try BeamObjectChecksum.savePreviousObject(beamObject: beamObject)
                    completion(.success(beamObject))
                } catch {
                    completion(.failure(error))
                }
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

                                _ = try self.saveToAPI(newBeamObject, deep: deep + 1, completion)
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

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(beamObjects: [BeamObject],
                                                           _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws {
        try fetchBeamObjects(beamObjects) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let remoteBeamObjects):
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

                        completion(.success(newObjects))
                    case .fetchRemoteAndError:
                        completion(.failure(BeamObjectManagerError.multipleErrors(remoteBeamObjects.map {
                            BeamObjectManagerError.invalidChecksum($0)
                        })))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Fetch remote object, and based on policy will either return the object with remote checksum, or return and error containing the remote object
    internal func fetchAndReturnErrorBasedOnConflictPolicy(_ beamObject: BeamObject,
                                                           _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws {
        try fetchBeamObject(beamObject: beamObject) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                /*
                 We tried fetching the remote beam object but it doesn't exist, we delete`previousChecksum`
                 */
                if case APIRequestError.notFound = error {
                    do {
                        try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)

                        switch self.conflictPolicyForSave {
                        case .replace:
                            completion(.success(beamObject))
                        case .fetchRemoteAndError:
                            completion(.failure(BeamObjectManagerError.invalidChecksum(beamObject)))
                        }
                    } catch {
                        completion(.failure(error))
                    }

                    return
                }
                completion(.failure(error))
            case .success(let remoteBeamObject):
                // This happened during tests, but could happen again if you have the same IDs for 2 different objects
                guard remoteBeamObject.beamObjectType == beamObject.beamObjectType else {
                    completion(.failure(BeamObjectManagerError.invalidObjectType(beamObject, remoteBeamObject)))
                    return
                }

                do {
                    switch self.conflictPolicyForSave {
                    case .replace:
                        try BeamObjectChecksum.savePreviousChecksum(beamObject: remoteBeamObject)

                        let newBeamObject = self.manageConflict(beamObject, remoteBeamObject)
                        completion(.success(newBeamObject))
                    case .fetchRemoteAndError:
                        completion(.failure(BeamObjectManagerError.invalidChecksum(remoteBeamObject)))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    @discardableResult
    internal func fetchBeamObjects<T: BeamObjectProtocol>(objects: [T],
                                                          _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            try request.fetchAllWithDataUrl(ids: objects.map { $0.beamObjectId },
                                            beamObjectType: T.beamObjectType.rawValue,
                                            completion)
        } else {
            try request.fetchAll(ids: objects.map { $0.beamObjectId },
                                 beamObjectType: T.beamObjectType.rawValue,
                                 completion)
        }
        return request
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
        if Configuration.beamObjectDataOnSeparateCall {
            try request.fetchAllWithDataUrl(ids: ids, completion)
        } else {
            try request.fetchAll(ids: ids, completion)
        }
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
                                   raisePrivateKeyError: Bool = false,
                                   _ completion: @escaping (Result<[BeamObject], Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        if Configuration.beamObjectDataOnSeparateCall {
            try request.fetchAllWithDataUrl(beamObjectType: beamObjectType, raisePrivateKeyError: raisePrivateKeyError, completion)
        } else {
            try request.fetchAll(beamObjectType: beamObjectType, raisePrivateKeyError: raisePrivateKeyError, completion)
        }
        return request
    }

    @discardableResult
    internal func fetchBeamObject(beamObject: BeamObject,
                                  _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        if Configuration.beamObjectDataOnSeparateCall {
            try request.fetchWithDataUrl(beamObject: beamObject, completion)
        } else {
            try request.fetch(beamObject: beamObject, completion)
        }
        return request
    }

    @discardableResult
    internal func fetchBeamObject<T: BeamObjectProtocol>(object: T,
                                                         _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()

        if Configuration.beamObjectDataOnSeparateCall {
            try request.fetchWithDataUrl(object: object, completion)
        } else {
            try request.fetch(object: object, completion)
        }

        return request
    }

    @discardableResult
    internal func fetchMinimalBeamObject(beamObject: BeamObject,
                                         _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchMinimalBeamObject(beamObject: beamObject, completion)
        return request
    }

    @discardableResult
    internal func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T,
                                                                _ completion: @escaping (Result<BeamObject, Error>) -> Void) throws -> APIRequest {
        let request = BeamObjectRequest()
        try request.fetchMinimalBeamObject(object: object, completion)
        return request
    }

    @discardableResult
    func delete<T: BeamObjectProtocol>(object: T,
                                       raise404: Bool = false,
                                       _ completion: ((Result<BeamObject?, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.delete(object: object) { result in
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

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }

    @discardableResult
    func delete(beamObject: BeamObject, raise404: Bool = false, _ completion: ((Result<BeamObject?, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        try BeamObjectChecksum.deletePreviousChecksum(beamObject: beamObject)
        let request = BeamObjectRequest()

        try request.delete(beamObject: beamObject) { result in
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

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }

    @discardableResult
    func deleteAll(_ beamObjectType: BeamObjectObjectType? = nil,
                   _ completion: ((Result<Bool, Error>) -> Void)? = nil) throws -> APIRequest {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw BeamObjectManagerError.notAuthenticated
        }

        let request = BeamObjectRequest()

        try request.deleteAll(beamObjectType: beamObjectType) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let success):
                do {
                    if let beamObjectType = beamObjectType {
                        try BeamObjectChecksum.deletePreviousChecksums(type: beamObjectType)
                    } else {
                        try BeamObjectChecksum.deleteAll()
                    }
                    completion?(.success(success))
                } catch {
                    completion?(.failure(error))
                }
            }
        }

        #if DEBUG
        DispatchQueue.main.async {
            Self.networkRequests.append(request)
        }
        #endif

        return request
    }
}
