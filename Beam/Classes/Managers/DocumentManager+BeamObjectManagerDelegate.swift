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

    private func receiveDeletedDocument(_ document: DocumentStruct) {
        // We can directly save deleted documents
        var doc = document
        doc.version += 1
        let semaphore = DispatchSemaphore(value: 0)
        save(doc, false, nil) { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Couln't save synced document \(document): \(error)", category: .document)
            case let .success(res):
                if !res {
                    Logger.shared.logError("Error while saving synced document \(document)", category: .document)
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    private func receiveConflictingLoadedDocument(_ document: DocumentStruct, note: BeamNote) {
        // We have a local note loaded with the same id, let's update it inline:
        guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: false) else { return }
        if document.title != note.title {
            remoteNote.title = document.title
            DispatchQueue.mainSync {
                note.updateTitle(remoteNote.title)
            }
        }
        let ancestorStruct = document.previousSavedObject ?? document
        guard let ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false) else { return }

        DispatchQueue.mainSync {
            // We have to block the main thread to merge the document
            // other wise the editor may have a race condition
            note.merge(other: remoteNote, ancestor: ancestorNote, advantageOther: false)
            _ = note.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)
        }
    }

    private func receiveConflictingLoadedJournal(_ document: DocumentStruct, note: BeamNote) {
        // there a conflicting journal note (with the same day)
        guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: true) else { return }
        DispatchQueue.mainSync {
            // We have to block the main thread to merge the document
            // other wise the editor may have a race condition

            // Do we have a different id?
            if remoteNote.id == note.id {
                // then we merge the changes in the local note
                let ancestorStruct = document.previousSavedObject ?? document
                let ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false)
                note.merge(other: remoteNote, ancestor: ancestorNote ?? note, advantageOther: false)
                _ = note.syncedSave()
            } else {
                remoteNote.concatenate(other: note)
                let documentManager = DocumentManager()
                let semaphore = DispatchSemaphore(value: 0)
                documentManager.softDelete(id: note.id) { result in
                    switch result {
                    case let .failure(error):
                        Logger.shared.logError("Error while soft deleting redundant journal note  \(document.titleAndId): \(error)", category: .document)
                    case let .success(res):
                        if !res {
                            Logger.shared.logError("Error while soft deleting redundant journal note \(document.titleAndId)", category: .document)
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                _ = remoteNote.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)
            }
        }
    }

    private func receiveConflictingJournal(_ document: DocumentStruct, withDate journalDate: String) {
        guard let localDocument = fetchWithJournalDate(journalDate)
        else {
            // There is no local journal document for said date, we can treat it as a normal doc:
            receiveDocument(document)
            return
        }

        let localStruct = DocumentStruct(document: localDocument)
        guard let localNote = try? BeamNote.instanciateNote(localStruct, keepInMemory: false) else {
            // The local document is unreadable, might have been deleted? Let's store this one then
            Logger.shared.logError("Unable to instantiate local journal note \(localStruct.titleAndId)", category: .document)
            receiveDocument(document)
            return
        }

        guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: false) else {
            // We can't instantiate the remote note either, all it lost...
            Logger.shared.logError("Unable to instantiate remote journal note \(document.titleAndId)", category: .document)
            return
        }

        remoteNote.concatenate(other: localNote)
        let documentManager = DocumentManager()
        let semaphore = DispatchSemaphore(value: 0)
        documentManager.softDelete(id: localNote.id) { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Error while soft deleting redundant journal note  \(localNote.titleAndId): \(error)", category: .document)
            case let .success(res):
                if !res {
                    Logger.shared.logError("Error while soft deleting redundant journal note \(document.titleAndId)", category: .document)
                }
            }
            semaphore.signal()
        }
        semaphore.wait()

        DispatchQueue.mainSync {
            _ = remoteNote.syncedSave(alsoWaitForNetworkSave: Self.waitForNetworkCompletionOnSyncSave)
        }
    }

    func newTitleForConflict(_ title: String) -> String? {
        let MAX_AUTO_INCREMENT = 100

        var (originalTitle, index) = title.originalTitleWithIndex()
        var newTitle = title
        repeat {
            newTitle = "\(originalTitle) (\(index))"
            index += 1
        } while index < MAX_AUTO_INCREMENT && (try? fetchWithTitle(newTitle)) != nil
        guard index < MAX_AUTO_INCREMENT else { return nil }
        return newTitle
    }

    func receiveConflictingTitleLoadedDocument(_ document: DocumentStruct, note: BeamNote) {
        let newTitle = newTitleForConflict(note.title) ?? note.titleAndId
        DispatchQueue.mainSync {
            note.updateTitle(newTitle)
        }
        let semaphore = DispatchSemaphore(value: 0)
        var doc = document
        if doc.version > 0 {
            // Start at zero if this note it new
            doc.version += 1
        }
        save(doc, false, nil) { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Unable to save new note \(document.titleAndId): \(error)", category: .document)
            case let .success(res):
                if !res {
                    Logger.shared.logError("Unable to save new note \(document.titleAndId)", category: .document)
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    func receiveConflictingTitleDocument(_ document: DocumentStruct, localDocument: DocumentStruct) {
        guard let localNote = try? BeamNote.instanciateNote(localDocument, keepInMemory: false) else {
            Logger.shared.logError("Unable to load existing note to rename \(localDocument.titleAndId)", category: .document)
            return
        }

        guard !localNote.isEntireNoteEmpty() else {
            let semaphore = DispatchSemaphore(value: 0)
            softDelete(id: localNote.id) { _ in
                semaphore.signal()
            }
            semaphore.wait()

            var localStruct: DocumentStruct?
            if let localDocument = try? fetchWithId(document.id, includeDeleted: true) {
                localStruct = DocumentStruct(document: localDocument)
            }
            receiveDocument(document, localDocument: localStruct)
            return
        }
        receiveConflictingTitleLoadedDocument(document, note: localNote)
    }

    private func receiveDocument(_ document: DocumentStruct, localDocument: DocumentStruct? = nil) {
        let semaphore = DispatchSemaphore(value: 0)
        var doc = document
        if let localDocument = localDocument {
            if localDocument.deletedAt != nil {
                delete(document: localDocument) { result in
                    Logger.shared.logDebug("Deleted already softdeleted \(localDocument.titleAndId) (there is a new one comming from the sync)",
                                           category: .document)
                }
            } else {
                doc.version = localDocument.version + 1

                if document.title != localDocument.title {
                    DispatchQueue.mainSync {
                        BeamNote.updateTitleLocally(id: document.id, document.title)
                    }
                }
            }
        }
        save(doc, false, nil) { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Error while saving document \(document.titleAndId) from sync: \(error)", category: .document)
            case let .success(res):
                if !res {
                    Logger.shared.logError("Error while saving document \(document.titleAndId) from sync", category: .document)
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    internal func receivedObjectsInContext(_ documents: [DocumentStruct]) throws {
        for document in documents {
            if document.deletedAt != nil {
                receiveDeletedDocument(document)
            } else if let journalDate = document.journalDate,
                      let date = BeamNoteType.dateFrom(journalDateString: journalDate) {
                if let note = BeamNote.getFetchedNote(date) {
                    receiveConflictingLoadedJournal(document, note: note)
                } else {
                    receiveConflictingJournal(document, withDate: journalDate)
                }
            } else if let note = BeamNote.getFetchedNote(document.title), note.id != document.id {
                receiveConflictingTitleLoadedDocument(document, note: note)
            } else if let localDocument = try? fetchWithTitle(document.title), localDocument.id != document.id {
                    receiveConflictingTitleDocument(document, localDocument: DocumentStruct(document: localDocument))
            } else if let note = BeamNote.getFetchedNote(document.id) {
                receiveConflictingLoadedDocument(document, note: note)
            } else if let localDocument = try? fetchWithId(document.id, includeDeleted: true) {
                let localStruct = DocumentStruct(document: localDocument)
                receiveDocument(document, localDocument: localStruct)
            } else {
                receiveDocument(document)
            }
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
            let decoder = BeamJSONDecoder()
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
