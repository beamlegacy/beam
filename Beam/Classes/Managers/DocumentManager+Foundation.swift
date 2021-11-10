// swiftlint:disable file_length

import Foundation
import BeamCore
import Combine

extension DocumentManager {
    // MARK: -
    // MARK: Create
    func fetchOrCreateAsync(title: String, completion: ((DocumentStruct?) -> Void)? = nil) {
        backgroundQueue.async { [unowned self] in
            let documentManager = DocumentManager()
            do {
                let document = try documentManager.fetchOrCreateWithTitle(title)
                completion?(self.parseDocumentBody(document))
            } catch {
                completion?(nil)
            }
        }
    }

    func createAsync(id: UUID, title: String, completion: ((Swift.Result<DocumentStruct, Error>) -> Void)? = nil) {
        backgroundQueue.async { [unowned self] in
            let documentManager = DocumentManager()
            do {
                let document: Document = try documentManager.create(id: id, title: title)
                completion?(.success(self.parseDocumentBody(document)))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Refresh

    /// Fetch most recent document from API
    /// First we fetch the remote updated_at, if it's more recent we fetch all details
    func refresh(_ documentStruct: DocumentStruct,
                 _ forced: Bool = false,
                 completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        try refreshFromBeamObjectAPIAndSaveLocally(documentStruct, forced, completion)
    }

    func refreshFromBeamObjectAPIAndSaveLocally(_ documentStruct: DocumentStruct,
                                                _ forced: Bool = false,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            throw APIRequestError.notAuthenticated
        }

        try refreshFromBeamObjectAPI(documentStruct, forced) { result in
            switch result {
            case .failure(let error): completion?(.failure(error))
            case .success(let remoteDocumentStruct):
                guard let remoteDocumentStruct = remoteDocumentStruct else {
                    Logger.shared.logDebug("\(documentStruct.title): remote is not more recent",
                                           category: .documentNetwork)
                    completion?(.success(false))
                    return
                }

                guard remoteDocumentStruct != documentStruct else {
                    Logger.shared.logDebug("\(documentStruct.title): remote is equal to stored version, skip",
                                           category: .documentNetwork)
                    completion?(.success(false))
                    return
                }

                // Saving the remote version locally
                self.backgroundQueue.async { [unowned self] in
                    let documentManager = DocumentManager()

                    do {
                        let document = try documentManager.fetchOrCreateWithId(documentStruct.id)
                        Logger.shared.logDebug("Fetched \(remoteDocumentStruct.title) {\(remoteDocumentStruct.id)} with previous checksum \(remoteDocumentStruct.checksum ?? "-")",
                                               category: .documentNetwork)
                        document.beam_object_previous_checksum = remoteDocumentStruct.checksum

                        if !self.mergeDocumentWithNewData(document, remoteDocumentStruct) {
                            document.data = remoteDocumentStruct.data
                        }
                        document.update(remoteDocumentStruct)
                        document.version += 1

                        try documentManager.checkValidations(document)

                        self.notificationDocumentUpdate(DocumentStruct(document: document))

                        completion?(.success(try documentManager.saveContext()))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: -
    // MARK: Save

    static func cancelAllPreviousThrottledAPICall() {
        Self.networkTasksSemaphore.wait()
        defer { Self.networkTasksSemaphore.signal() }

        Logger.shared.logDebug("Cancel all \(Self.networkTasks.keys.count) previous network tasks",
                               category: .documentNetwork)

        Self.networkTasks.forEach { (_, tuple) in
            if tuple.1 == false {
                tuple.0.cancel()
                tuple.2?(.failure(DocumentManagerError.operationCancelled))
            }
        }
    }

    static func cancelPreviousThrottledAPICall(_ documentStructId: UUID) {
        Self.networkTasksSemaphore.wait()
        defer { Self.networkTasksSemaphore.signal() }

        guard let tuple = Self.networkTasks[documentStructId] else {
            Logger.shared.logDebug("No previous network task for {\(documentStructId)}",
                                   category: .documentNetwork)
            return
        }

        Logger.shared.logDebug("Cancel previous network task for {\(documentStructId)}",
                               category: .documentNetwork)
        tuple.0.cancel()

        // `cancelPreviousThrottledAPICall` is called when there are conflicts, the completionHandler will be called
        // by the code calling `cancelPreviousThrottledAPICall`, we don't need to do it ourselve.
        // Calling it here means `networkCompletion` from `save()` could be called multiple times.
        // tuple.1?(.failure(DocumentManagerError.operationCancelled))
    }

    /// `save()` throttles network calls, this is calling API immediately.
    func saveThenSaveOnAPI(_ documentStruct: DocumentStruct,
                           completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        Self.cancelPreviousThrottledAPICall(documentStruct.id)

        self.save(documentStruct, false, completion: { result in
            switch result {
            case .failure:
                completion?(result)
            case .success(let success):
                guard success == true else {
                    completion?(result)
                    return
                }

                self.saveDocumentStructOnAPI(documentStruct) { result in
                    completion?(result)
                }
            }
        })
    }

    /// `saveDocument` will save locally in CoreData then call the completion handler
    /// If the user is authenticated, and network is enabled, it will also call the BeamAPI (async) to save the document remotely
    /// but will not trigger the completion handler. If the network callbacks updates the coredata object, it is expected the
    /// updates to be fetched through `onDocumentChange`
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func save(_ documentStruct: DocumentStruct,
              _ networkSave: Bool = true,
              _ networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil,
              completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logDebug("Saving \(documentStruct.titleAndId)", category: .document)
        Logger.shared.logDebug(documentStruct.data.asString ?? "-", category: .documentDebug)

        Self.saveOperationsSemaphore.wait()
        defer { Self.saveOperationsSemaphore.signal() }

        let blockOperation = BlockOperation()
        if let saveOperation = Self.saveOperations[documentStruct.id] {
            Logger.shared.logDebug("Existing save operation, cancelling it", category: .document)
            saveOperation.cancel()
        }
        Self.saveOperations[documentStruct.id] = blockOperation

        blockOperation.addExecutionBlock { [weak blockOperation, weak self] in
            guard let self = self,
                  let blockOperation = blockOperation
            else { return }

            // In case the operationqueue was cancelled way before this started
            if blockOperation.isCancelled {
                completion?(.failure(DocumentManagerError.operationCancelled))
                return
            }

            let documentManager = DocumentManager()

            do {
                let document = try documentManager.fetchOrCreateWithId(documentStruct.id)
                document.update(documentStruct)
                document.data = documentStruct.data
                document.updated_at = BeamDate.now
                try documentManager.checkValidations(document)
                try documentManager.checkVersion(document, documentStruct.version)
                document.version = documentStruct.version

                if let database = try? Database.fetchWithId(documentManager.context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion?(.failure(error))
                return
            }

            if blockOperation.isCancelled {
                completion?(.failure(DocumentManagerError.operationCancelled))
                return
            }

            do {
                try documentManager.saveContext()
            } catch {
                completion?(.failure(error))
                return
            }

            // Ping others about the update
            self.notificationDocumentUpdate(documentStruct)

            if blockOperation.isCancelled {
                completion?(.failure(DocumentManagerError.operationCancelled))
                return
            }

            completion?(.success(true))

            // If not authenticated, we don't need to send to BeamAPI
            if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled, networkSave {
                self.saveAndThrottle(documentStruct, 1.0, networkCompletion)
            } else {
                networkCompletion?(.failure(APIRequestError.notAuthenticated))
            }

            DispatchQueue.main.async {
                guard Self.saveOperations[documentStruct.id] === blockOperation else { return }
                Self.saveOperations.removeValue(forKey: documentStruct.id)
            }
        }

        Self.saveDocumentQueue.addOperation(blockOperation)
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    internal func saveDocumentStructOnAPI(_ documentStruct: DocumentStruct,
                                          _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> APIRequest? {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return nil
        }

        do {
            var documentStruct = documentStruct.copy()

            documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum
            let document_id = documentStruct.id

            return try self.saveOnBeamObjectAPI(documentStruct) { result in
                Self.networkTasksSemaphore.wait()
                Self.networkTasks.removeValue(forKey: document_id)
                Self.networkTasksSemaphore.signal()

                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success: completion?(.success(true))
                }
            }
        } catch {
            completion?(.failure(error))
            return nil
        }
    }

    @discardableResult
    func saveOnApi(_ documentStruct: DocumentStruct,
                   _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> APIRequest? {
        do {
            var documentStruct = documentStruct.copy()

            documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum
            let document_id = documentStruct.id

            let apiRequest = try self.saveOnBeamObjectAPI(documentStruct) { result in
                Self.networkTasksSemaphore.wait()
                Self.networkTasks.removeValue(forKey: document_id)
                Self.networkTasksSemaphore.signal()

                switch result {
                case .failure(let error): completion?(.failure(error))
                case .success: completion?(.success(true))
                }
            }

            return apiRequest
        } catch {
            completion?(.failure(error))
            return nil
        }
    }

    /// If the note we tried saving on the API is new and empty, we can safely delete it.
    /// If the note we tried saving already has content, we soft delete it to avoid losing content.
    private func deleteOrSoftDelete(_ localDocumentStruct: DocumentStruct,
                                    _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        // This is a new document, we can delete it
        guard !localDocumentStruct.isEmpty else {
            self.delete(id: localDocumentStruct.id) { result in
                Logger.shared.logDebug("Deleted \(localDocumentStruct.titleAndId)",
                                       category: .document)
                completion?(result)
            }
            return
        }

        // This is a document with local changes, we soft delete it

        var newDocumentStruct = localDocumentStruct.copy()
        newDocumentStruct.deletedAt = BeamDate.now

        saveThenSaveOnAPI(newDocumentStruct) { result in
            switch result {
            case .failure:
                completion?(result)
            case .success(let success):
                Logger.shared.logDebug("Soft deleted \(newDocumentStruct.titleAndId)",
                                       category: .document)
                completion?(.success(success))
            }
        }
    }

    // MARK: -
    // MARK: Delete

    func softDelete(ids: [UUID], completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        var errors: [Error] = []
        var goodObjects: [DocumentStruct] = []
        backgroundQueue.async { [unowned self] in
            let documentManager = DocumentManager()
            for id in ids {
                guard let document = try? documentManager.fetchWithId(id) else {
                    errors.append(DocumentManagerError.idNotFound)
                    continue
                }

                if let database = try? Database.fetchWithId(documentManager.context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("No connected database", category: .document)
                }

                var documentStruct = DocumentStruct(document: document)
                documentStruct.deletedAt = BeamDate.now
                documentStruct.previousChecksum = documentStruct.beamObjectPreviousChecksum

                document.deleted_at = documentStruct.deletedAt
                goodObjects.append(documentStruct)

                // Ping others about the update
                self.notificationDocumentUpdate(documentStruct)
            }

            do {
                try documentManager.saveContext()
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion(.failure(error))
                return
            }

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated,
                  Configuration.networkEnabled else {
                completion(.success(false))
                return
            }

            do {
                try self.saveOnBeamObjectsAPI(goodObjects) { result in
                    guard errors.isEmpty else {
                        completion(.failure(DocumentManagerError.multipleErrors(errors)))
                        return
                    }

                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success: completion(.success(true))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    func softDelete(id: UUID, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        self.softDelete(ids: [id], completion: completion)
    }

    /**
     You should *not* use this unless you know what you're doing, deleting objects prevent the deletion to be propagated
     to other devices through the API. Use `softDelete` instead.

     Good scenario examples to use `delete`:

     - you know the note has not been propagated yet (previousChecksums are nil)
     - you're adding this in a debug window for developers (like DocumentDetail)
     */
    func delete(ids: [UUID], completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        ids.forEach { Self.cancelPreviousThrottledAPICall($0) }

        var errors: [Error] = []
        var goodIds: [UUID] = []
        backgroundQueue.async { [unowned self] in
            let documentManager = DocumentManager()
            for id in ids {
                guard let document: Document = try? documentManager.fetchWithId(id) else {
                    errors.append(DocumentManagerError.idNotFound)
                    continue
                }

                if let database = try? Database.fetchWithId(documentManager.context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("No connected database", category: .document)
                }

                let documentStruct = DocumentStruct(document: document)
                document.delete(documentManager.context)
                goodIds.append(id)

                // Ping others about the update
                self.notificationDocumentDelete(documentStruct)
            }

            do {
                try documentManager.saveContext()
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion(.failure(error))
                return
            }

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated,
                  Configuration.networkEnabled else {
                completion(.success(false))
                return
            }

            do {
                try self.deleteFromBeamObjectAPI(goodIds) { result in
                    guard errors.isEmpty else {
                        completion(.failure(DocumentManagerError.multipleErrors(errors)))
                        return
                    }

                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /**
     You should *not* use this unless you know what you're doing, deleting objects prevent the deletion to be propagated
     to other devices through the API. Use `softDelete` instead.
     */
    func delete(id: UUID, _ networkDelete: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        self.delete(ids: [id], completion: completion)
    }

    /// WARNING: this will delete *ALL* documents, including from different databases.
    func deleteAll(includedRemote: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        do {
            try deleteAll(databaseId: nil)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .coredata)
        }

        guard includedRemote else {
            completion(.success(true))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion(.success(false))
            return
        }
        Self.cancelAllPreviousThrottledAPICall()

        do {
            try deleteAllFromBeamObjectAPI(completion)
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: -
    // MARK: Bulk calls
    func fetchAllOnApi(_ completion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        try self.fetchAllFromBeamObjectAPI { result in
            switch result {
            case .failure(let error):
                completion?(.failure(error))
            case .success(let databases):
                do {
                    try self.receivedObjects(databases)
                    completion?(.success(true))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    func saveAllOnAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        backgroundQueue.async {
            let documentManager = DocumentManager()
            documentManager.context.performAndWait {
                do {
                    let documents = (try? documentManager.fetchAll(filters: [.allDatabases, .includeDeleted])) ?? []

                    Logger.shared.logDebug("Uploading \(documents.count) documents", category: .documentNetwork)
                    if documents.count == 0 {
                        completion?(.success(true))
                        return
                    }

                    // Cancel previous saves as we're saving all of the objects anyway
                    Self.cancelAllPreviousThrottledAPICall()

                    let documentStructs = documents.map { DocumentStruct(document: $0) }
                    try self.saveOnBeamObjectsAPI(documentStructs) { result in
                        switch result {
                        case .failure(let error):
                            Logger.shared.logError(error.localizedDescription, category: .documentNetwork)
                            completion?(.failure(error))
                        case .success:
                            completion?(.success(true))
                        }
                    }
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }

    // MARK: -
    // MARK: Database related
    func moveAllOrphanNotes(databaseId: UUID, _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        backgroundQueue.async { [unowned self] in
            let documentManager = DocumentManager()
            do {
                let databaseIds = DatabaseManager().all().map { $0.id }

                let orphanDocuments = try documentManager.fetchAll(filters: [.notDatabaseIds(databaseIds), .includeDeleted])

                for document in orphanDocuments {
                    document.database_id = databaseId
                }

                try context.save()

                if !orphanDocuments.isEmpty {
                    UserAlert.showMessage(message: "\(orphanDocuments.count) documents impacted, must exit.", buttonTitle: "Exit now")
                    NSApplication.shared.terminate(nil)
                } else {
                    UserAlert.showMessage(message: "no document impacted")
                }
                completion(.success(true))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
