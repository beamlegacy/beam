import Foundation
import BeamCore

extension DocumentManager {
    /// Use this to have updates when the underlaying CD object `Document` changes
    func onDocumentChange(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentChange called for \(documentStruct.titleAndId)", category: .documentDebug)

        var documentId = documentStruct.id
        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                guard let updatedDocuments = notification.userInfo?["updatedDocuments"] as? [DocumentStruct] else {
                    return
                }

                for document in updatedDocuments {

                    /*
                     I used to prevent calling `completionHandler` when that condition was true:

                     `if let documentManager = notification.object as? DocumentManager, documentManager == self { return }`

                     to avoid the same DocumentManager to return its own saved update.

                     But we have legit scenarios when such is happening, for example when there is an API conflict,
                     and the manager fetch, merge and resave that merged object.

                     We need the UI to be updated about such to reflect the merge.
                     */

                    if document.title == documentStruct.title &&
                        document.databaseId == documentStruct.databaseId &&
                        document.id != documentId {

                        /*
                         When a document is deleted and overwritten because of a title conflict, we want to let
                         the editor know to update the editor UI with the new document.

                         However when going on the "see all notes" debug window, and forcing a document refresh,
                         we don't want the editor UI to change.
                         */

                        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
                        context.performAndWait {
                            guard let coreDataDocument = try? Document.fetchWithId(context, documentId) else {
                                Logger.shared.logDebug("notification for \(document.titleAndId) (new id)",
                                                       category: .documentNotification)
                                documentId = document.id
                                completionHandler(document)
                                return
                            }

                            if documentStruct.deletedAt == nil, coreDataDocument.deleted_at != documentStruct.deletedAt {
                                Logger.shared.logDebug("notification for \(document.titleAndId) (new id)",
                                                       category: .documentNotification)
                                documentId = document.id
                                completionHandler(document)
                            } else {
                                Logger.shared.logDebug("No notification for \(document.titleAndId) (new id)",
                                                       category: .documentNotification)
                            }
                        }
                    } else if document.id == documentId {
                        Logger.shared.logDebug("notification for \(document.titleAndId)",
                                               category: .documentNotification)
                        completionHandler(document)
                    } else if document.title == documentStruct.title {
                        Logger.shared.logDebug("notification for \(document.titleAndId) but not detected. onDocumentChange() called with \(documentStruct.titleAndId), {\(documentId)}",
                                               category: .documentNotification)
                    }
                }
            }
        return cancellable
    }

    func onDocumentDelete(_ documentStruct: DocumentStruct,
                          completionHandler: @escaping (DocumentStruct) -> Void) -> AnyCancellable {
        Logger.shared.logDebug("onDocumentDelete called for \(documentStruct.titleAndId)", category: .documentDebug)

        let cancellable = NotificationCenter.default
            .publisher(for: .documentUpdate)
            .sink { notification in
                // Skip notification coming from this manager
                if let documentManager = notification.object as? DocumentManager, documentManager == self {
                    return
                }

                if let deletedDocuments = notification.userInfo?["deletedDocuments"] as? [DocumentStruct] {
                    for document in deletedDocuments where document.id == documentStruct.id {
                        Logger.shared.logDebug("notification for \(document.titleAndId)", category: .document)
                        try? GRDBDatabase.shared.remove(noteTitled: document.title)
                        completionHandler(document)
                    }
                }
            }
        return cancellable
    }

    // MARK: -
    // MARK: Create
    func create(title: String) -> DocumentStruct? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: DocumentStruct?

        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.create(context, title: title)

            do {
                try self.checkValidations(context, document)

                result = self.parseDocumentBody(document)
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .coredata)
            }

            semaphore.signal()
        }

        semaphore.wait()

        return result
    }

    func fetchOrCreateAsync(title: String, completion: ((DocumentStruct?) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { [unowned self] context in
            let document = Document.fetchOrCreateWithTitle(context, title)
            do {
                try self.checkValidations(context, document)
                try Self.saveContext(context: context)
                completion?(self.parseDocumentBody(document))
            } catch {
                completion?(nil)
            }
        }
    }

    func createAsync(title: String, completion: ((Swift.Result<DocumentStruct, Error>) -> Void)? = nil) {
        coreDataManager.backgroundContext.perform { [unowned self] in
            let context = self.coreDataManager.backgroundContext
            let document = Document.create(context, title: title)
            do {
                try self.checkValidations(context, document)
                try Self.saveContext(context: context)
                completion?(.success(self.parseDocumentBody(document)))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Refresh

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
                self.coreDataManager.persistentContainer.performBackgroundTask { context in
                    let document = Document.rawFetchOrCreateWithId(context, documentStruct.id)

                    do {
                        Logger.shared.logDebug("Fetched \(remoteDocumentStruct.title) {\(remoteDocumentStruct.id)} with previous checksum \(remoteDocumentStruct.checksum ?? "-")",
                                               category: .documentNetwork)
                        document.beam_object_previous_checksum = remoteDocumentStruct.checksum

                        if !self.mergeDocumentWithNewData(document, remoteDocumentStruct) {
                            document.data = remoteDocumentStruct.data
                        }
                        document.update(remoteDocumentStruct)
                        document.version += 1

                        try self.checkValidations(context, document)

                        self.notificationDocumentUpdate(DocumentStruct(document: document))

                        completion?(.success(try Self.saveContext(context: context)))
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
            tuple.0.cancel()
            tuple.1?(.failure(DocumentManagerError.operationCancelled))
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

        var blockOperation: BlockOperation!

        blockOperation = BlockOperation { [weak self] in
            guard let self = self else { return }

            // In case the operationqueue was cancelled way before this started
            if blockOperation.isCancelled {
                completion?(.failure(DocumentManagerError.operationCancelled))
                return
            }
            let context = self.coreDataManager.backgroundContext

            context.performAndWait { [weak self] in
                guard let self = self else { return }

                if blockOperation.isCancelled {
                    completion?(.failure(DocumentManagerError.operationCancelled))
                    return
                }

                let document = Document.rawFetchOrCreateWithId(context, documentStruct.id)
                document.update(documentStruct)
                document.data = documentStruct.data
                document.updated_at = BeamDate.now
                if let journalDate = documentStruct.journalDate {
                    document.journal_day = JournalDateConverter.toInt(from: journalDate)
                }

                do {
                    try self.checkValidations(context, document)
                    try self.checkVersion(context, document, documentStruct.version)
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .document)
                    completion?(.failure(error))
                    return
                }

                document.version = documentStruct.version

                if let database = try? Database.rawFetchWithId(context, document.database_id) {
                    database.updated_at = BeamDate.now
                } else {
                    // We should always have a connected database
                    Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                }

                if blockOperation.isCancelled {
                    completion?(.failure(DocumentManagerError.operationCancelled))
                    return
                }

                do {
                    try Self.saveContext(context: context)
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
            }
        }

        saveOperations[documentStruct.id]?.cancel()
        saveOperations[documentStruct.id] = blockOperation
        saveDocumentQueue.addOperation(blockOperation)
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

    private func saveDocumentStructOnAPISuccess(_ documentStruct: DocumentStruct,
                                                _ beam_api_sent_at: Date,
                                                _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        coreDataManager.persistentContainer.performBackgroundTask { context in
            guard let documentCoreData = try? Document.fetchWithId(context, documentStruct.id) else {
                completion?(.failure(DocumentManagerError.localDocumentNotFound))
                return
            }

            // We save the remote stored version of the document, to know if we have local changes later
            // `beam_api_data` stores the last version we sent to the API
            // `beam_api_checksum` stores the checksum we sent to the API
            documentCoreData.beam_api_data = documentStruct.data
            documentCoreData.beam_api_checksum = documentStruct.previousChecksum
            documentCoreData.beam_api_sent_at = beam_api_sent_at

            do {
                let success = try Self.saveContext(context: context)
                completion?(.success(success))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: -
    // MARK: Delete
    func delete(_ ids: [UUID]) throws {
        let group = DispatchGroup()
        var errors: [Error] = []
        let lock = DispatchSemaphore(value: 1)

        for id in ids {
            group.enter()
            delete(id: id) { result in
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

        if let error = errors.first {
            throw error
        }
    }

    func delete(id: UUID, _ networkDelete: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        Self.cancelPreviousThrottledAPICall(id)

        coreDataManager.persistentContainer.performBackgroundTask { context in

            guard let document = try? Document.fetchWithId(context, id) else {
                completion(.failure(DocumentManagerError.idNotFound))
                return
            }

            if let database = try? Database.rawFetchWithId(context, document.database_id) {
                database.updated_at = BeamDate.now
            } else {
                // We should always have a connected database
                Logger.shared.logError("No connected database", category: .document)
            }

            let documentStruct = DocumentStruct(document: document)
            document.delete(context)

            do {
                try Self.saveContext(context: context)
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion(.failure(error))
                return
            }

            // Ping others about the update
            self.notificationDocumentDelete(documentStruct)

            // If not authenticated
            guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled, networkDelete else {
                completion(.success(false))
                return
            }

            do {
                try self.deleteFromBeamObjectAPI(id, completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deleteAll(includedRemote: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        do {
            try Document.deleteWithPredicate(CoreDataManager.shared.mainContext)
            try Self.saveContext(context: CoreDataManager.shared.mainContext)
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

    func saveAllOnAPI(_ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else {
            completion?(.success(false))
            return
        }

        CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
            do {
                let sent_all_at = BeamDate.now
                let documents = (try? Document.rawFetchAll(context, self.predicateForSaveAll())) ?? []

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
                        Logger.shared.logDebug("Documents uploaded", category: .documentNetwork)
                        Persistence.Sync.Documents.sent_all_at = sent_all_at
                        context.performAndWait {
                            // TODO: do this with `NSBatchUpdateRequest` for performance
                            for document in documents { document.beam_api_sent_at = sent_all_at }
                            try? CoreDataManager.save(context)
                        }
                        completion?(.success(true))
                    }
                }
            } catch {
                completion?(.failure(error))
            }
        }
    }
}
