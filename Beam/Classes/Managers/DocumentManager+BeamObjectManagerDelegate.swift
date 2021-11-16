import Foundation
import BeamCore

extension DocumentManager: BeamObjectManagerDelegate {
    func willSaveAllOnBeamObjectApi() {
        Self.cancelAllPreviousThrottledAPICall()
    }

    func saveObjectsAfterConflict(_ objects: [DocumentStruct]) throws {
        for updateObject in objects {
            guard let documentCoreData = try fetchWithId(updateObject.id) else {
                throw DocumentManagerError.localDocumentNotFound
            }

            guard !self.isEqual(documentCoreData, to: updateObject) else { continue }

            documentCoreData.data = updateObject.data
            documentCoreData.beam_object_previous_checksum = updateObject.previousChecksum
            documentCoreData.beam_api_data = updateObject.data
            documentCoreData.version += 1

            do {
                try checkValidations(documentCoreData)
            } catch {
                Logger.shared.logError("saveObjectsAfterConflict checkValidations: \(error.localizedDescription)",
                                       category: .database)
                documentCoreData.deleted_at = BeamDate.now
            }

            let savedDoc = DocumentStruct(document: documentCoreData)
            self.notificationDocumentUpdate(savedDoc)
            indexDocument(savedDoc)
        }
        try saveContext()
    }

    static var conflictPolicy: BeamObjectConflictResolution = .fetchRemoteAndError

    func persistChecksum(_ objects: [DocumentStruct]) throws {
        var changed = false

        try context.performAndWait {
            for updateObject in objects {
                guard let documentCoreData = try? fetchWithId(updateObject.id) else {
                    throw DocumentManagerError.localDocumentNotFound
                }

                /*
                 `persistChecksum` might be called more than once for the same object, if you save one object and
                 it conflicts, once merged it will call saveOnBeamAPI() again and there will be no way to know this
                 2nd save doesn't need to persist checksum, unless passing a method attribute `dontSaveChecksum`
                 which is annoying as a pattern.

                 Instead I just check if it's the same, with same previous data and we skip the save to avoid a
                 CD save.
                 */
                guard documentCoreData.beam_object_previous_checksum != updateObject.previousChecksum ||
                        documentCoreData.beam_api_data != updateObject.data else {
                    continue
                }

                Logger.shared.logDebug("PersistChecksum \(updateObject.titleAndId) with previous checksum \(updateObject.previousChecksum ?? "-")",
                                       category: .documentNetwork)
                documentCoreData.beam_object_previous_checksum = updateObject.previousChecksum
                documentCoreData.beam_api_data = updateObject.data

                changed = true
            }

            if changed { try saveContext() }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func receivedObjects(_ documents: [DocumentStruct]) throws {
        var changedDocuments: Set<DocumentStruct> = Set()

        var changed = false

        let documentManager = DocumentManager()
        for var document in documents {
            guard var localDocument = try? documentManager.fetchOrCreateWithId(document.id) else {
                Logger.shared.logError("Received object \(document.titleAndId), but could't create it localy, skip",
                                       category: .documentNetwork)
                continue
            }

            guard !self.isEqual(localDocument, to: document) else { continue }

            if document.checksum == localDocument.beam_object_previous_checksum &&
                document.data == localDocument.beam_api_data {
                Logger.shared.logDebug("Received object \(document.titleAndId), but has same checksum \(document.checksum ?? "-") and previous data, skip",
                                       category: .documentNetwork)
                continue
            }

            var good = false
            var (originalTitle, index) = document.title.originalTitleWithIndex()

            while !good && index < 10 {
                do {
                    if localDocument.objectID.isTemporaryID || !self.mergeDocumentWithNewData(localDocument, document) {
                        localDocument.data = document.data
                    }

                    localDocument.update(document)
                    Logger.shared.logDebug("Received object \(document.titleAndId), set previous checksum \(document.checksum ?? "-")",
                                           category: .documentNetwork)

                    localDocument.beam_object_previous_checksum = document.checksum
                    localDocument.version += 1

                    try checkValidations(localDocument)

                    let savedDoc = DocumentStruct(document: localDocument)
                    self.notificationDocumentUpdate(savedDoc)
                    indexDocument(savedDoc)

                    good = true
                    changed = true
                } catch {
                    guard (error as NSError).domain == "DOCUMENT_ERROR_DOMAIN" else {
                        Logger.shared.logError(error.localizedDescription, category: .documentNetwork)
                        throw error
                    }

                    switch (error as NSError).code {
                    case 1001:
                        let conflictedDocuments = (error as NSError).userInfo["documents"] as? [DocumentStruct]

                        // When receiving empty documents from the API and conflict with existing documents,
                        // we delete them if they're empty. That happens with today's journal for example

                        // Remote document is empty, we delete it
                        if document.isEmpty {
                            document.deletedAt = BeamDate.now
                            localDocument.deleted_at = document.deletedAt
                            Logger.shared.logWarning("Title is in conflict but remote document is empty, deleting",
                                                     category: .documentNetwork)

                            changedDocuments.insert(document)
                            // Local document is empty, we either delete it if never saved, or soft delete it
                        } else if let conflictedDocuments = conflictedDocuments,
                                  !conflictedDocuments.compactMap({ $0.isEmpty }).contains(false) {
                            // local conflicted documents are empty, deleting them
                            for localConflictedDocument in conflictedDocuments {
                                guard let localConflictedDocumentCD = try? fetchWithId(localConflictedDocument.id) else { continue }

                                // We already saved this document, we must propagate its deletion
                                if localConflictedDocumentCD.beam_api_sent_at != nil {
                                    localConflictedDocumentCD.deleted_at = BeamDate.now
                                    changedDocuments.insert(DocumentStruct(document: localConflictedDocumentCD))
                                    Logger.shared.logWarning("Title is in conflict, but local documents are empty, soft deleting",
                                                             category: .documentNetwork)
                                } else {
                                    context.delete(localConflictedDocumentCD)
                                    Logger.shared.logWarning("Title is in conflict, but local documents are empty, deleting",
                                                             category: .documentNetwork)
                                }
                            }

                        } else {
                            document.title = "\(originalTitle) (\(index))"
                            Logger.shared.logWarning("Title is in conflict, neither local or remote are empty.",
                                                     category: .documentNetwork)
                            changedDocuments.insert(document)
                        }

                        index += 1
                    case 1002:
                        Logger.shared.logWarning("Version \(localDocument.version) is higher than \(document.version)",
                                                 category: .documentNetwork)
                        localDocument = try fetchOrCreateWithId(document.id)
                        Logger.shared.logWarning("After reload: \(localDocument.version)",
                                                 category: .documentNetwork)
                    case 1003:
                        Logger.shared.logError("journalDate is incorrect: \(error.localizedDescription)", category: .documentNetwork)
                        if let documents = (error as NSError).userInfo["documents"] as? [DocumentStruct] {
                            dump(documents)
                        }
                        document.deletedAt = BeamDate.now
                        localDocument.deleted_at = document.deletedAt
                        changedDocuments.insert(document)
                        good = true
                        changed = true
                    case 1004:
                        Logger.shared.logError("Error saving, journal date conflicts: \(error.localizedDescription). Deleting it.",
                                               category: .document)
                        if let documents = (error as NSError).userInfo["documents"] as? [DocumentStruct] {
                            dump(documents)
                        }

                        document.deletedAt = BeamDate.now
                        localDocument.deleted_at = document.deletedAt
                        changedDocuments.insert(document)
                        good = true
                        changed = true
                    default:
                        Logger.shared.logError("Error saving: \(error.localizedDescription). Deleting it.",
                                               category: .document)

                        document.deletedAt = BeamDate.now
                        localDocument.deleted_at = document.deletedAt
                        changedDocuments.insert(document)
                        good = true
                        changed = true
                    }
                }
            }
        }

        if changed {
            try saveContext()
        }

        if !changedDocuments.isEmpty {
            let semaphore = DispatchSemaphore(value: 0)
            try saveOnBeamObjectsAPI(Array(changedDocuments)) { _ in
                semaphore.signal()
            }

            let semaphoreResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(10))
            if case .timedOut = semaphoreResult {
                Logger.shared.logError("Semaphore timedout", category: .documentNetwork)
            }
        }

        if !changedDocuments.isEmpty {
            Logger.shared.logDebug("Received \(documents.count) documents: done. \(changedDocuments.count) remodified.",
                                   category: .documentNetwork)
        }
    }

    func indexDocument(_ docStruct: DocumentStruct) {
        BeamNote.indexingQueue.async {
            let decoder = JSONDecoder()
            do {
                let note = try decoder.decode(BeamNote.self, from: docStruct.data)
                try GRDBDatabase.shared.append(note: note)
            } catch {
                Logger.shared.logError("Error while trying to index synced note '\(docStruct.title)' [\(docStruct.id)]: \(error)", category: .document)
            }
        }
    }

    func allObjects(updatedSince: Date?) throws -> [DocumentStruct] {
        // Note: when this becomes a memory hog because we manipulate all local documents, we'll want to loop through
        // them by 100s and make multiple network calls instead.
        var filters: [DocumentFilter] = [.includeDeleted]
        if let updatedSince = updatedSince {
            filters.append(.updatedSince(updatedSince))
        }

        // This method is called across threads so we need to create a local documentManager to have fetchAll be safe:
        let documentManager = DocumentManager()
        let allDocuments = try documentManager.fetchAll(filters: filters)
        let allDocStrucs: [DocumentStruct] = allDocuments.map {
            var result = DocumentStruct(document: $0)
            result.previousChecksum = result.beamObjectPreviousChecksum
            return result
        }
        return allDocStrucs
    }

    func checksumsForIds(_ ids: [UUID]) throws -> [UUID: String] {
        let documentManager = DocumentManager()
        let values: [(UUID, String)] = try documentManager.fetchAllWithIds(ids).compactMap {
            var result = DocumentStruct(document: $0)
            result.previousChecksum = result.beamObjectPreviousChecksum
            guard let previousChecksum = result.previousChecksum else { return nil }
            return (result.beamObjectId, previousChecksum)
        }

        return Dictionary(uniqueKeysWithValues: values)
    }

    private func saveDatabaseAndDocumentOnBeamObjectAPI(_ documentStruct: DocumentStruct,
                                                        _ completion: @escaping ((Swift.Result<Bool, Error>) -> Void)) throws {
        var dbStruct: DatabaseStruct?
        guard let dbDatabase = try Database.fetchWithId(context, documentStruct.databaseId) else { return }
        dbStruct = DatabaseStruct(database: dbDatabase)

        guard let databaseStruct = dbStruct else {
            throw DatabaseManagerError.localDatabaseNotFound
        }

        let databaseManager = DatabaseManager()

        // TODO: add a way to cancel the database API calls
        _ = try databaseManager.saveOnBeamObjectAPI(databaseStruct) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                do {
                    try self.saveOnBeamObjectAPI(documentStruct) { result in
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
    }

    func manageConflict(_ documentStruct: DocumentStruct,
                        _ remoteDocumentStruct: DocumentStruct) throws -> DocumentStruct {
        Logger.shared.logWarning("Could not save \(documentStruct.titleAndId) because of conflict", category: .documentNetwork)

        var result = documentStruct.copy()

        // Merging might fail, in such case we send the remote version of the document
        let document = try fetchOrCreateWithId(documentStruct.id)
        if let beam_api_data = document.beam_api_data,
           let data = BeamElement.threeWayMerge(ancestor: beam_api_data,
                                                input1: documentStruct.data,
                                                input2: remoteDocumentStruct.data) {
            Logger.shared.logDebug("Could merge both automatically", category: .documentNetwork)
            result.data = data
        } else {
            // We can't save the most recent one as it's always be the local version, as we update `updatedAt` way
            // too often.
            Logger.shared.logWarning("Could not merge both automatically, resending remote document",
                                     category: .documentNetwork)
        }
        result.version = document.version

        if let beamNote = try? BeamNote.instanciateNote(result, keepInMemory: false, decodeChildren: true) {
            Logger.shared.logDebug(beamNote.textDescription(), category: .documentNetwork)
        }

        // Not incrementing `version` on purpose, this is only used to send the merged object back to the API
        result.updatedAt = BeamDate.now

        return result
    }
}
