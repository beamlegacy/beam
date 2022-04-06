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
                let document: Document = try documentManager.fetchOrCreate(title, deletedAt: nil)
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
                let document: Document = try documentManager.create(id: id, title: title, deletedAt: nil)
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

    // swiftlint:disable function_body_length
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
                    Logger.shared.logDebug("\(documentStruct.title): remote is not more recent, skip",
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
                self.saveDocumentQueue.async { [unowned self] in
                    let documentManager = DocumentManager()

                    do {
                        let document: Document = try documentManager.fetchOrCreate(documentStruct.id, title: documentStruct.title, deletedAt: documentStruct.deletedAt)
                        Logger.shared.logDebug("Fetched \(remoteDocumentStruct.title) {\(remoteDocumentStruct.id)} with previous checksum \(try remoteDocumentStruct.checksum())",
                                               category: .documentNetwork)

                        if !documentManager.mergeDocumentWithNewData(document, remoteDocumentStruct) {
                            document.data = remoteDocumentStruct.data
                        }
                        document.update(remoteDocumentStruct)
                        document.version += 1

                        try documentManager.checkValidations(document)

                        // Once we locally saved the remote object, we want to update the local previous Checksum to
                        // avoid non-existing conflicts
                        try BeamObjectChecksum.savePreviousChecksum(object: remoteDocumentStruct)
                        let success = try documentManager.saveContext()

                        /*
                         Spent *hours* on that problem. The new `DocumentManager` instance is saving the coredata object,
                         but the `context` attached to `self` seems to return an old version of the coredata object unless
                         we force and refresh that object manually...
                         */
                        self.context.perform {
                            if let localStoredDocument = try? self.fetchWithId(documentStruct.id, includeDeleted: true) {
                                self.context.refresh(localStoredDocument, mergeChanges: false)

                                #if DEBUG
                                assert(localStoredDocument.data == document.data)
                                #endif
                            } else {
                                assert(false)
                            }
                        }

                        try BeamObjectChecksum.savePreviousObject(object: remoteDocumentStruct)

                        #if DEBUG
                        if let localStoredDocumentStruct = documentManager.loadById(id: documentStruct.id, includeDeleted: true) {
                            dump(localStoredDocumentStruct)
                            assert(localStoredDocumentStruct.data == document.data)
                        } else {
                            assert(false)
                        }
                        #endif

                        completion?(.success(success))
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

        guard !Self.networkTasks.keys.isEmpty else { return }

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

        saveDocumentQueue.async {
            let documentManager = DocumentManager()

            do {
                let document: Document = try documentManager.fetchOrCreate(documentStruct.id, title: documentStruct.title, deletedAt: documentStruct.deletedAt)
                try documentManager.context.performAndWait {
                    document.update(documentStruct)
                    document.data = documentStruct.data
                    try documentManager.checkValidations(document)
                    if document.version > 0 {
                        try documentManager.checkVersion(document, documentStruct.version)
                    }

                    document.version = documentStruct.version

                    if let database = try? Database.fetchWithId(documentManager.context, document.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("Didn't find database \(document.database_id)", category: .document)
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .document)
                completion?(.failure(error))
                networkCompletion?(.failure(DocumentManagerError.networkNotCalled))
                return
            }

            do {
                try documentManager.saveContext()

                /*
                 Spent *hours* on that problem. The new `DocumentManager` instance is saving the coredata object,
                 but the `context` attached to `self` seems to return an old version of the coredata object unless
                 we force and refresh that object manually...

                 Don't use performAndWait as it creates a DEADLOCK
                 */

                self.context.perform {
                    // Quick Fix: `self.thread` is supposed to be the one from inside the context thread, no the thread where the
                    // document manager instance was created. This is a quick fix to not break the checks but there is
                    // something fishy around `checkThread()` which should check the current thread is one from a `perform()`
                    let oldThread = self.thread
                    defer { self.thread = oldThread }

                    self.thread = Thread.current
                    if let localStoredDocument = try? self.fetchWithId(documentStruct.id, includeDeleted: true) {
                        self.context.refresh(localStoredDocument, mergeChanges: false)
                    }
                }

            } catch {
                completion?(.failure(error))
                networkCompletion?(.failure(DocumentManagerError.networkNotCalled))
                return
            }

            completion?(.success(true))

            // If not authenticated, we don't need to send to BeamAPI
            if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled, networkSave {
                documentManager.saveAndThrottle(documentStruct, 1.0, networkCompletion)
            } else {
                networkCompletion?(.failure(APIRequestError.notAuthenticated))
            }
        }
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
            Logger.shared.logError(error.localizedDescription, category: .documentNetwork)
            completion?(.failure(error))
            return nil
        }
    }

    @discardableResult
    func saveOnApi(_ documentStruct: DocumentStruct,
                   _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) -> APIRequest? {
        do {
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
            delete(document: localDocumentStruct) { result in
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

    func softDelete(ids: [UUID], clearData: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        var errors: [Error] = []
        var goodObjects: [DocumentStruct] = []
        saveDocumentQueue.async {
            let documentManager = DocumentManager()
            for id in ids {
                guard let document = try? documentManager.fetchWithId(id, includeDeleted: false) else {
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

                document.deleted_at = documentStruct.deletedAt
                if clearData {
                    documentStruct.data = Data()
                    document.data = Data()
                }

                goodObjects.append(documentStruct)
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

    func softUndelete(ids: [UUID], restoreData: [UUID: Data]? = nil, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        var errors: [Error] = []
        var goodObjects: [DocumentStruct] = []
        saveDocumentQueue.async {
            let documentManager = DocumentManager()
            for id in ids {
                guard let document = try? documentManager.fetchWithId(id, includeDeleted: true) else {
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
                documentStruct.deletedAt = nil
                document.deleted_at = nil
                if let data = restoreData?[id] {
                    documentStruct.data = data
                    document.data = data
                }
                goodObjects.append(documentStruct)
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

    func softUndelete(id: UUID, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        self.softUndelete(ids: [id], completion: completion)
    }

    /**
     You should *not* use this unless you know what you're doing, deleting objects prevent the deletion to be propagated
     to other devices through the API. Use `softDelete` instead.

     Good scenario examples to use `delete`:

     - you know the note has not been propagated yet (previousChecksums are nil)
     - you're adding this in a debug window for developers (like DocumentDetail)
     - You're deleting documents in test scenarios
     */
    // swiftlint:disable function_body_length
    func delete(documents: [DocumentStruct], completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        documents.forEach { Self.cancelPreviousThrottledAPICall($0.beamObjectId) }

        var errors: [Error] = []
        var goods: [DocumentStruct] = []

        /*
         1. Using saveDocumentQueue to ensure it's done in background else `documentManager.context` will be the main one,
            and no RACE conditions with `save`. 
         2. Then using `context.perform` because that's how CD should be used, always in the context's thread
         3. Then setting `documentManager.thread` so `checkThread()` is happy
         4. Then using `defer` to set it back to its previous value
         */
        saveDocumentQueue.async {
            Logger.shared.logDebug("Deleting \(documents.map { $0.titleAndId }.joined(separator: ", "))",
                                   category: .document)

            let documentManager = DocumentManager()
            documentManager.context.performAndWait {
                let oldThread = documentManager.thread
                documentManager.thread = Thread.current
                defer { documentManager.thread = oldThread }

                for document in documents {
                    guard let cdDocument: Document = try? documentManager.fetchWithId(document.id, includeDeleted: true) else {
                        errors.append(DocumentManagerError.idNotFound)
                        continue
                    }

                    if let database = try? Database.fetchWithId(documentManager.context, cdDocument.database_id) {
                        database.updated_at = BeamDate.now
                    } else {
                        // We should always have a connected database
                        Logger.shared.logError("No connected database", category: .document)
                    }

                    documentManager.context.refresh(cdDocument, mergeChanges: false)
                    documentManager.context.delete(cdDocument)
                    do {
                        try documentManager.saveContext()
                    } catch {
                        Logger.shared.logError(error.localizedDescription, category: .coredata)
                        completion(.failure(error))
                        return
                    }
                    goods.append(document)
                }

                // If not authenticated
                guard AuthenticationManager.shared.isAuthenticated,
                      Configuration.networkEnabled else {
                    completion(.success(false))
                    return
                }

                do {
                    try self.deleteFromBeamObjectAPI(objects: goods) { result in
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
    }

    /**
     You should *not* use this unless you know what you're doing, deleting objects prevent the deletion to be propagated
     to other devices through the API. Use `softDelete` instead.
     */
    func delete(document: DocumentStruct, _ networkDelete: Bool = true, completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        delete(documents: [document], completion: completion)
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
            case .success(let documents):
                do {
                    try self.receivedObjects(documents)
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
    //swiftlint:disable:next cyclomatic_complexity function_body_length
    func moveAllOrphanNotes(databaseId: UUID, onlyOrphans: Bool, _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) {
        let documentManager = DocumentManager()
        do {
            let databaseIds = DatabaseManager().all().map { $0.id }
            let filters: [DocumentFilter] = onlyOrphans ? [.notDatabaseIds(databaseIds), .includeDeleted] : [.notDatabaseIds([databaseId]), .includeDeleted]
            var count = 0
            for document in try documentManager.fetchAll(filters: filters) {
                let noteId = document.id
                guard let note = BeamNote.fetch(id: noteId, includeDeleted: true, keepInMemory: false, verifyDatabase: false),
                      note.databaseId != databaseId
                else { continue }

                // make sure we don't have duplicate notes:
                if note.type.isJournal {
                    if let date = note.type.journalDate {
                        if let existingNote = BeamNote.fetch(journalDate: date, keepInMemory: false), note.id != existingNote.id, !note.isEntireNoteEmpty() {
                            // This is a journal note, if we have a collision we must take this contents and move it to the end the existing note of the same day

                            if existingNote.isEntireNoteEmpty() {
                                // we just replace the children with the one from the local note
                                existingNote.children = []
                            }

                            for child in note.children {
                                guard let content = child.deepCopy(withNewId: false, selectedElements: nil, includeFoldedChildren: true) else { continue }
                                existingNote.children.append(content)
                            }
                            existingNote.resetCommandManager()
                            _ = existingNote.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)

                            // Delete source note:
                            documentManager.softDelete(id: note.id) { result in
                                switch result {
                                case let .failure(error):
                                    Logger.shared.logError("Failed to softDelete \(note.titleAndId): \(error)", category: .document)
                                case let .success(res):
                                    if !res {
                                        Logger.shared.logError("Failed to softDelete \(note.titleAndId)", category: .document)
                                    }
                                }
                            }
                        } else {
                            note.databaseId = databaseId
                            _ = note.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)
                        }

                    }
                } else {
                    // This is a regular note, if we have a collision we need to add an index to the end of the name until we find a non colliding name:
                    // First make sure it doesn't already exist in the destination DB:
                    var note = note
                    if documentManager.fetchAllNames(filters: [.id(note.id)]).count != 0 {
                        // ID Conflict!
                        // This note was already synced in a past life, let's rename it and change its id in the new DB
                        guard let noteCopy = note.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) else {
                            Logger.shared.logError("Unable to duplicate note \(note.titleAndId)", category: .document)
                            continue
                        }
                        documentManager.softDelete(id: note.id) { result in
                            switch result {
                            case let .failure(error):
                                Logger.shared.logError("Error during soft delete of note \(note.titleAndId): \(error)", category: .document)
                            case let .success(res):
                                if !res {
                                    Logger.shared.logError("Unable to soft delete note \(note.titleAndId)", category: .document)
                                }
                            }
                        }
                        note = noteCopy
                    }

                    // Check for titles duplicates:
                    let allTitles = Set(documentManager.fetchAllNames(filters: [.databaseId(databaseId)]))
                    var index = 0
                    var title = note.title
                    let maxCount = allTitles.count + 1
                    while allTitles.contains(title) && index < maxCount {
                        // we have a conflict, let's try to find a non clonflicting note:
                        index += 1
                        title = note.title + " (\(index))"
                    }

                    note.title = title
                    note.databaseId = databaseId
                    _ = note.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)
                }
                count += 1
            }
            completion(.success(true))
        } catch {
            completion(.failure(error))
        }
    }
}
