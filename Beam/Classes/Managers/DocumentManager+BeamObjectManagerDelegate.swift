import Foundation
import BeamCore

extension DocumentManager: BeamObjectManagerDelegate {
    func willSaveAllOnBeamObjectApi() {
        Self.cancelAllPreviousThrottledAPICall()
    }

    func saveObjectsAfterConflict(_ objects: [DocumentStruct]) throws {
        let documentManager = DocumentManager()

        try documentManager.saveDocumentQueue.sync {
            for updateObject in objects {
                guard let documentCoreData = try documentManager.fetchWithId(updateObject.id, includeDeleted: false) else {
                    throw DocumentManagerError.localDocumentNotFound
                }

                guard !self.isEqual(documentCoreData, to: updateObject) else { continue }

                documentCoreData.data = updateObject.data
                documentCoreData.version += 1

                do {
                    let documentManager = DocumentManager()
                    try documentManager.checkValidations(documentCoreData)
                } catch {
                    Logger.shared.logError("saveObjectsAfterConflict checkValidations: \(error.localizedDescription)",
                                           category: .database)
                    documentCoreData.deleted_at = BeamDate.now
                }

                let savedDoc = DocumentStruct(document: documentCoreData)
                indexDocument(savedDoc)
            }
            try documentManager.saveContext()
        }
    }

    static var conflictPolicy: BeamObjectConflictResolution = .fetchRemoteAndError

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func receivedObjectsInContext(_ documents: [DocumentStruct]) throws {
        var changedDocuments: Set<DocumentStruct> = Set()

        try saveDocumentQueue.sync {
            var changed = false

            for var document in documents {
                let fakeDate = Date.distantPast
                guard var localDocument: Document = try? fetchOrCreate(document.id,
                                                                       title: document.title,
                                                                       deletedAt: fakeDate,
                                                                       shouldSaveContext: false) else {
                    Logger.shared.logError("Received object \(document.titleAndId), but could't create it localy, skip",
                                           category: .documentNetwork)
                    continue
                }

                guard !self.isEqual(localDocument, to: document) else { continue }

                // We may have used a fake date to make sure we could create the document,
                // let's restore it to it's correct date before other modifications to make it sure we can save it later:
                if localDocument.deleted_at == fakeDate {
                    localDocument.deleted_at = document.deletedAt
                }

                var good = false
                var (originalTitle, index) = document.title.originalTitleWithIndex()

                while !good && index < 10 {
                    do {
                        if localDocument.version == 0 || localDocument.data == nil || !mergeDocumentWithNewData(localDocument, document) {
                            localDocument.data = document.data
                        }

                        localDocument.update(document)
                        // Don't want to pollute logs with tons of lines
                        if documents.count < 5 {
                            Logger.shared.logDebug("Received object \(document.titleAndId) update",
                                                   category: .documentNetwork)
                        }

                        localDocument.version += 1

                        try checkValidations(localDocument)

                        let savedDoc = DocumentStruct(document: localDocument)
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
                                    guard let localConflictedDocumentCD = try? fetchWithId(localConflictedDocument.id, includeDeleted: false) else { continue }

                                    // We already saved this document, we must propagate its deletion
                                    if BeamObjectChecksum.previousChecksum(object: document) != nil {
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
                            localDocument = try fetchOrCreate(document.id, title: document.title, deletedAt: document.deletedAt)
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

    func receivedObjects(_ documents: [DocumentStruct]) throws {
        let documentManager = DocumentManager()
        try documentManager.context.performAndWait {
            try documentManager.receivedObjectsInContext(documents)
        }
    }

    func indexDocument(_ docStruct: DocumentStruct) {
        BeamNote.indexingQueue.addOperation {
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
            DocumentStruct(document: $0)
        }
        return allDocStrucs
    }

    func manageConflict(_ documentStruct: DocumentStruct,
                        _ remoteDocumentStruct: DocumentStruct) throws -> DocumentStruct {
        Logger.shared.logWarning("Could not save \(documentStruct.titleAndId) because of conflict", category: .documentNetwork)

        var result = documentStruct.copy()
        let documentManager = DocumentManager()

        return try documentManager.saveDocumentQueue.sync {
            // Merging might fail, in such case we send the remote version of the document
            let document = try documentManager.fetchOrCreate(documentStruct.id,
                                                             title: documentStruct.title,
                                                             deletedAt: documentStruct.deletedAt)
            if let beam_api_data = documentStruct.previousSavedObject?.data,
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
}
