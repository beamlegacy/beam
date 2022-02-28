//
//  BeamNote+DocumentManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//
//swiftlint:disable file_length

import Foundation
import BeamCore
import Atomics

extension BeamNote: BeamNoteDocument {
    var documentStruct: DocumentStruct? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(self)
            #if DEBUG
            // an empty BeamNote encoded to JSon is at lease 250 bytes
            assert(data.count > 250, "data should encode a full note, it shouldn't be empty (trying to create a documentStruct out of \(self)")
            #endif
            guard var docStruct = documentStructLight else { return nil }
            docStruct.data = data
            return docStruct
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }

    /// This version of DocumentStruct doesn't contain the encoded data. If must only be used for observing task
    var documentStructLight: DocumentStruct? {
        if databaseId == nil {
            Logger.shared.logError("DatabaseID should already have been set", category: .document)
        }

        let structDBId = databaseId ?? DatabaseManager.defaultDatabase.id

        return DocumentStruct(id: id,
                              databaseId: structDBId,
                              title: title,
                              createdAt: creationDate,
                              updatedAt: updateDate,
                              data: Data(),
                              documentType: type.isJournal ? .journal : .note,
                              version: version.load(ordering: .relaxed),
                              isPublic: publicationStatus.isPublic,
                              journalDate: type.journalDateString)
    }

    static var purgingNotes = Set<UUID>()
    static func updateNote(_ documentStruct: DocumentStruct) {
        guard documentStruct.deletedAt == nil else {
            purgeDeletedNode(documentStruct.id)
            return
        }

        guard let note = Self.getFetchedNote(documentStruct.id) else {
            return
        }

        note.updateAttempts += 1
        /*
         When receiving updates for a new document, we don't check the version
         */
        if note.version.load(ordering: .relaxed) >= documentStruct.version, note.id == documentStruct.id {
            Logger.shared.logDebug("\(note.titleAndId) observer skipped \(documentStruct.version) (must be > \(note.version.load(ordering: .relaxed)))",
                                   category: .documentNotification)
            return
        }

        note.changePropagationEnabled = false
        defer {
            note.changePropagationEnabled = true
        }

        Logger.shared.logDebug("updateNote received for \(documentStruct.titleAndId)",
                               category: .documentNotification)

        note.updateWithDocumentStruct(documentStruct)
    }

    static func purgeDeletedNode(_ id: UUID) {
        beamCheckMainThread()
        guard let note = Self.getFetchedNote(id) else {
            return
        }

        note.deleted = true
        unload(note: note)

        note.links.map({ $0.noteID }).forEach { id in
            guard let note = BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false) else { return }
            note.recursiveChangePropagationEnabled = false
            note.updateNoteNamesInInternalLinks(recursive: true)
            _ = note.syncedSave()
            note.recursiveChangePropagationEnabled = true
        }

        do {
            try GRDBDatabase.shared.remove(noteId: note.id)
        } catch {
            Logger.shared.logError("Impossible to remove all notes from indexing: \(error)", category: .search)
        }
    }

    func updateWithDocumentStruct(_ docStruct: DocumentStruct, file: StaticString = #file, line: UInt = #line) {
        beamCheckMainThread()
        let context = "file: \(file):\(line)"
        if self.version.load(ordering: .relaxed) >= docStruct.version, self.id == docStruct.id {
            Logger.shared.logDebug("\(self.titleAndId) update skipped \(docStruct.version) (must be > \(self.version.load(ordering: .relaxed))) [caller: \(context)]",
                                   category: .document)
            return
        }

        self.updates += 1
        let decoder = JSONDecoder()
        guard let newSelf = try? decoder.decode(BeamNote.self, from: docStruct.data) else {
            Logger.shared.logError("Unable to decode new documentStruct \(docStruct.title) {\(docStruct.id)} [caller: \(context)]",
                                   category: .document)
            return
        }

        if self.id != newSelf.id {
            // TODO: reprocess bidirectional links, the document we had has been replaced with a new one
            // following a title conflict
            self.id = newSelf.id
        }
        self.title = newSelf.title
        self.type = newSelf.type
        self.searchQueries = newSelf.searchQueries
        self.visitedSearchResults = newSelf.visitedSearchResults

        self.version.store(docStruct.version, ordering: .relaxed)
        self.databaseId = docStruct.databaseId
        self.deleted = docStruct.deletedAt != nil

        self.savedVersion.store(self.version.load(ordering: .relaxed), ordering: .relaxed)

        Logger.shared.logDebug("updateWithDocumentStruct updating \(title) - \(id) [caller: \(context)]", category: .document)
        recursiveUpdate(other: newSelf)
    }

    public func updateTitle(_ newTitle: String) {
        beamCheckMainThread()
        let previousTitle = self.title
        try? GRDBDatabase.shared.remove(note: self)
        self.title = newTitle
        if getFetchedNote(self.id) != nil {
            // Only reload the note if it was already loaded
            Self.reloadAfterRename(previousTitle: previousTitle, note: self)
        }
        indexContents()
        Logger.shared.logInfo("Rename \(previousTitle) to \(title) [\(id)]", category: .document)
//        AppDelegate.main.data.renamedNote = (id, previousTitle, title)

        _ = syncedSave(alsoWaitForNetworkSave: DocumentManager.waitForNetworkCompletionOnSyncSave)

        for link in links {
            guard let element = link.element else { continue }
            element.updateNoteNamesInInternalLinks(recursive: true)
            _ = element.note?.syncedSave()
        }
    }

    static public func updateTitleLocally(id: UUID, _ newTitle: String) {
        beamCheckMainThread()
        guard let previousTitle = BeamNote.titleForNoteId(id, true) else { return }
        try? GRDBDatabase.shared.remove(noteId: id)
        if let note = getFetchedNote(id) {
            // Only reload the note if it was already loaded
            Self.reloadAfterRename(previousTitle: previousTitle, note: note)
        }
        Logger.shared.logInfo("Rename \(previousTitle) to \(newTitle) [\(id)]", category: .document)

        let links = (try? GRDBDatabase.shared.fetchLinks(toNote: id).map({ bidiLink in
            BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
        })) ?? []

        for link in links {
            guard let element = link.element else { continue }
            element.updateNoteNamesInInternalLinks(recursive: true)
            _ = element.note?.syncedSave()
        }
    }

    public func indexContents() {
        beamCheckMainThread()
        sign.begin(Signs.indexContents, titleAndId)
        try? GRDBDatabase.shared.append(note: self)
        sign.end(Signs.indexContents)
    }

    public func syncedSave(alsoWaitForNetworkSave: Bool = false) -> Bool {
        sign.begin(Signs.syncedSave, titleAndId)
        var saved = false
        let saveSemaphore = DispatchSemaphore(value: 0)
        let networkSemaphore = DispatchSemaphore(value: 0)
        save(networkSave: true, networkCompletion: { _ in
            networkSemaphore.signal()
        }, completion: { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Failed to save note \(self): \(error)", category: .document)
            case .success(let res):
                saved = res
                if !res {
                    Logger.shared.logError("Unable to save note \(self)", category: .document)
                }
            }

            saveSemaphore.signal()
        })
        saveSemaphore.wait()
        if alsoWaitForNetworkSave {
            networkSemaphore.wait()
        }

        sign.end(Signs.syncedSave)
        return saved
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func save(networkSave: Bool = true, networkCompletion: ((Swift.Result<Bool, Error>) -> Void)? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        beamCheckMainThread()
        sign.begin(Signs.save, titleAndId)
        guard !saving.load(ordering: .relaxed) && version.load(ordering: .relaxed) == savedVersion.load(ordering: .relaxed) else {
            Logger.shared.logWarning("Waiting for last save: \(title) {\(id)} - saved version \(savedVersion.load(ordering: .relaxed)) / current \(version.load(ordering: .relaxed))",
                                     category: .document)
            completion?(.failure(BeamNoteError.saveAlreadyRunning))
            sign.end(Signs.save)
            return
        }

        saving.store(true, ordering: .relaxed)

        /*
         When saving the note, we must increment its version first. `documentManager.save()` will check for
         version increase between saves.
         */

        version.wrappingIncrement(ordering: .relaxed)

        guard let documentStruct = documentStruct else {
            version.wrappingDecrement(ordering: .relaxed)
            Logger.shared.logError("Unable to find active document struct \(titleAndId)", category: .document)
            saving.store(false, ordering: .relaxed)
            completion?(.failure(BeamNoteError.unableToCreateDocumentStruct))
            sign.end(Signs.save)
            return
        }

        #if DEBUG
        assert(!documentStruct.data.isEmpty)
        #endif

        guard !documentStruct.data.isEmpty else {
            Logger.shared.logInfo("BeamNote '\(titleAndId)' save error: empty data", category: .document)
            completion?(.failure(BeamNoteError.dataIsEmpty))
            sign.end(Signs.save)
            return
        }

        // Index saved notes:
        indexContents()

        Logger.shared.logInfo("BeamNote wants to save: \(titleAndId)", category: .document)
        let documentManager = DocumentManager()
        documentManager.save(documentStruct, networkSave, networkCompletion, completion: { result in
            switch result {
            case .success(let success):
                guard success else { break }
                // TSAN: We need to sync dispatch it to the main thread to make sure it doesn't create a data race.
                self.savedVersion.store(self.version.load(ordering: .relaxed), ordering: .relaxed)
                self.pendingSave.store(0, ordering: .relaxed)

            case .failure(BeamNoteError.saveAlreadyRunning):
                self.pendingSave.wrappingIncrement(ordering: .relaxed)

            case .failure(let error):
                if (error as NSError).domain == "DOCUMENT_ERROR_DOMAIN" {
                    switch (error as NSError).code {
                    case 1002:
                        Logger.shared.logError("Version error with \(self.titleAndId), reloading from the DB", category: .document)

                        /*
                         The saved CoreData model has a higher version, and this instance of BeamNote didn't receive it
                         through `onDocumentChange`. This should never happen.

                         TODO: should merge the current version with the existing version instead of just reloading, to
                         avoid losing content.
                         */

                        /* This is the way you should handle the error in your completion handler:
                        if let dbDocumentStruct = documentManager.loadById(id: documentStruct.id) {
                            DispatchQueue.main.async {
                                self.updateWithDocumentStruct(dbDocumentStruct)
                            }
                        }

                        Logger.shared.logError("Version changed to \(self.savedVersion)/\(self.version)",
                                               category: .document)
                         */
                    case 1001:
                        Logger.shared.logError("Title already exists for \(self.titleAndId)",
                                               category: .document)

                        /*
                         Another non-deleted note with the same title, in the same database exists. We receive the
                         existing duplicate in the error. We overwrite the current note with the existing duplicate to
                         avoid UI glitch.

                         TODO: should merge the current version with the existing version instead of just reloading, to
                         avoid losing content.
                         */

                        if let documents = (error as NSError).userInfo["documents"] as? [DocumentStruct],
                           let existingDocument = documents.first {
                            Logger.shared.logError("\(documents.count) other documents, fetching existing one. Documents:",
                                                   category: .document)

                            dump(documents)

                            Logger.shared.logError("documentStruct:",
                                                   category: .document)
                            dump(documentStruct)

                            // We delete the passed documentStruct as it conflicts with existing
                            DocumentManager().delete(document: documentStruct) { _ in
                                DispatchQueue.main.async {
                                    self.updateWithDocumentStruct(existingDocument)
                                    self.savedVersion.store(existingDocument.version, ordering: .relaxed)
                                }

                                self.saving.store(false, ordering: .relaxed)
                                // remove all file references:
                                do {
                                    try BeamFileDBManager.shared.removeReference(fromNote: self.id, element: nil)
                                } catch {
                                    Logger.shared.logError("Error while updating file references for note \(self.titleAndId)", category: .document)
                                }

                                completion?(result)
                            }

                            // Avoid calling save() again
                            self.saving.store(false, ordering: .relaxed)
                            Self.signPost.end(Signs.save, id: self.sign)
                            return
                        }
                    case 1003:
                        Logger.shared.logError("Error saving: \(error.localizedDescription)",
                                               category: .document)
                    case 1004:
                        Logger.shared.logError("Error saving, journal date conflicts: \(error.localizedDescription)",
                                               category: .document)
                        if let documents = (error as NSError).userInfo["documents"] as? [DocumentStruct] {
                            Logger.shared.logError("\(documents.count) other documents, fetching existing one. Documents:",
                                                   category: .document)

                            dump(documents)

                            Logger.shared.logError("documentStruct:",
                                                   category: .document)
                            dump(documentStruct)
                        }

                        self.saving.store(false, ordering: .relaxed)
                        completion?(.failure(error))
                        Self.signPost.end(Signs.save, id: self.sign)
                        return
                    default:
                        Logger.shared.logError("Error saving: \(error.localizedDescription)",
                                               category: .document)
                    }
                }

                self.version.store(self.savedVersion.load(ordering: .relaxed), ordering: .relaxed)
                Logger.shared.logError("Saving note \(self.titleAndId) failed: \(error)", category: .document)

                if self.pendingSave.load(ordering: .relaxed) > 0 {
                    DispatchQueue.main.async {
                        Logger.shared.logDebug("Trying again: Saving note \(self.titleAndId) as there were \(self.pendingSave) pending save operations",
                                               category: .document)
                        self.save(completion: completion)
                    }
                    return
                }
            }

            // remove all file references:
            do {
                try BeamFileDBManager.shared.removeReference(fromNote: self.id, element: nil)
                // and recreate them:
                for fileElement in self.allFileElements {
                    try BeamFileDBManager.shared.addReference(fromNote: self.id, element: fileElement.1.id, to: fileElement.0)
                }
            } catch {
                Logger.shared.logError("Error while updating file references for note \(self.titleAndId)", category: .document)
            }
            self.saving.store(false, ordering: .relaxed)
            completion?(result)
            Self.signPost.end(Signs.save, id: self.sign)
        })
    }

    static func instanciateNote(_ documentStruct: DocumentStruct,
                                keepInMemory: Bool = true,
                                decodeChildren: Bool = true,
                                verifyDatabase: Bool = true) throws -> BeamNote {

        if verifyDatabase && documentStruct.databaseId != DatabaseManager.defaultDatabase.id {
            Logger.shared.logError("We just tried loading a note from a database that is NOT the default database!", category: .database)
        }

        let decoder = JSONDecoder()
        if decodeChildren == false {
            decoder.userInfo[BeamElement.recursiveCoding] = false
        }
        let note = try decoder.decode(BeamNote.self, from: documentStruct.data)
        note.version.store(documentStruct.version, ordering: .relaxed)
        note.databaseId = documentStruct.databaseId
        note.savedVersion.store(note.version.load(ordering: .relaxed), ordering: .relaxed)
        note.updateDate = documentStruct.updatedAt
        note.deleted = documentStruct.deletedAt != nil
        if keepInMemory {
            appendToFetchedNotes(note)
        }
        return note
    }

    static func instanciateNoteWithPreviousData(_ documentStruct: DocumentStruct,
                                                decodeChildren: Bool = true) throws -> BeamNote? {
        let decoder = JSONDecoder()
        if decodeChildren == false {
            decoder.userInfo[BeamElement.recursiveCoding] = false
        }

        guard let previousData = BeamObjectChecksum.sentData(object: documentStruct) else { return nil }

        let note = try decoder.decode(BeamNote.self, from: previousData)
        note.version.store(documentStruct.version, ordering: .relaxed)
        note.databaseId = documentStruct.databaseId
        note.savedVersion.store(note.version.load(ordering: .relaxed), ordering: .relaxed)
        note.updateDate = documentStruct.updatedAt
        note.deleted = documentStruct.deletedAt != nil

        return note
    }

    public static func fetch(title: String,
                             keepInMemory: Bool = true,
                             decodeChildren: Bool = true) -> BeamNote? {
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchTitle, title)
        defer {
            sign.end(Signs.fetchTitle)
        }

        let documentManager = DocumentManager()
        // Is the note in the cache?
        if let note = getFetchedNote(title), !note.deleted {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentByTitle(title: title) else {
            return nil
        }

        do {
            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetch(journalDate: Date,
                             keepInMemory: Bool = true,
                             decodeChildren: Bool = true) -> BeamNote? {
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalDate, journalDate.description)
        defer {
            sign.end(Signs.fetchJournalDate)
        }
        let documentManager = DocumentManager()
        // Is the note in the cache?
        let title = BeamDate.journalNoteTitle(for: journalDate)
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentWithJournalDate(BeamNoteType.iso8601ForDate(journalDate)) else {
            return nil
        }

        //        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

        do {
            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetch(id: UUID,
                             includeDeleted: Bool,
                             keepInMemory: Bool = true, fetchFromMemory: Bool = true,
                             decodeChildren: Bool = true, verifyDatabase: Bool = true) -> BeamNote? {
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchId, id.uuidString)
        defer {
            sign.end(Signs.fetchId)
        }

        let documentManager = DocumentManager()
        if keepInMemory || fetchFromMemory {
            // Is the note in the cache?
            if let note = getFetchedNote(id) {
                return note
            }
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentById(id: id, includeDeleted: includeDeleted) else {
            return nil
        }

        do {
            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren, verifyDatabase: verifyDatabase)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetchNotesWithType(type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [BeamNote] {
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchNotesWithType)
        defer {
            sign.end(Signs.fetchNotesWithType)
        }
        beamCheckMainThread()
        let documentManager = DocumentManager()
        return documentManager.loadDocumentsWithType(type: type, limit, fetchOffset).compactMap { doc -> BeamNote? in
            if let note = getFetchedNote(doc.title) {
                return note
            }
            do {
                return try instanciateNote(doc)
            } catch {
                Logger.shared.logError("Unable to load document \(doc.title) (\(doc.id)): \(error.localizedDescription)", category: .document)
                return nil
            }
        }
    }

    public static func fetchJournalsFrom(date: String) -> [BeamNote] {
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalsFromDate, date)
        defer {
            sign.end(Signs.fetchJournalsFromDate)
        }

        let documentManager = DocumentManager()
        documentManager.checkThread()
        do {
            let todayInt = JournalDateConverter.toInt(from: date)

            return try documentManager.fetchAll(filters: [.type(.journal), .nonFutureJournalDate(todayInt)], sortingKey: .journal(false)).compactMap({ Self.fetch(id: $0.id, includeDeleted: false) })
        } catch { return [] }
    }

    public static func fetchJournalsBefore(count: Int, date: String) -> [BeamNote] {
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalsBefore, date)
        defer {
            sign.end(Signs.fetchJournalsBefore)
        }
        beamCheckMainThread()
        let documentManager = DocumentManager()
        documentManager.checkThread()
        do {
            let dateInt = JournalDateConverter.toInt(from: date)

            return try documentManager.fetchAll(filters: [.type(.journal), .beforeJournalDate(dateInt), .limit(count)], sortingKey: .journal(false)).compactMap({ Self.fetch(id: $0.id, includeDeleted: false) })
        } catch { return [] }
    }

    static private func insertDefaultFrecency(noteId: UUID) {
        AppDelegate.main.data.noteFrecencyScorer.update(id: noteId, value: 1.0, eventType: .noteCreate, date: BeamDate.now, paramKey: .note30d0)
        AppDelegate.main.data.noteFrecencyScorer.update(id: noteId, value: 1.0, eventType: .noteCreate, date: BeamDate.now, paramKey: .note30d1)
    }

    // Beware that this function crashes whatever note with that title in the cache
    public static func create(title: String) -> BeamNote {
        let sign = Self.signPost.createId()
        sign.begin(Signs.createTitle, title)
        defer {
            sign.end(Signs.createTitle)
        }
        beamCheckMainThread()
        assert(getFetchedNote(title) == nil)
        let note = BeamNote(title: title)
        note.databaseId = DatabaseManager.defaultDatabase.id

        Self.insertDefaultFrecency(noteId: note.id)
        appendToFetchedNotes(note)
        updateNoteCount()
        _ = note.syncedSave()
        return note
    }

    public static func create(journalDate: Date) -> BeamNote {
        let sign = Self.signPost.createId()
        sign.begin(Signs.createJournalDate, journalDate.description)
        defer {
            sign.end(Signs.createJournalDate)
        }
        beamCheckMainThread()
        let note = BeamNote(journalDate: journalDate)
        note.databaseId = DatabaseManager.defaultDatabase.id

        Self.insertDefaultFrecency(noteId: note.id)
        // TODO: should force a first quick save to trigger any title conflicts with the API asap
        appendToFetchedNotes(note)
        updateNoteCount()
        _ = note.syncedSave()
        return note
    }

    public func autoSave() {
        beamCheckMainThread()
        AppDelegate.main.data.noteAutoSaveService.addNoteToSave(self)
    }

    public static func fetchOrCreate(title: String) -> BeamNote {
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchOrCreate, title)
        defer {
            sign.end(Signs.fetchOrCreate)
        }
        beamCheckMainThread()
        // Is the note in the cache?
        if let note = fetch(title: title) {
            return note
        }

        // create a new note and add it to the cache
        return create(title: title)
    }

    public static func fetchOrCreateJournalNote(date: Date) -> BeamNote {
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchOrCreateJournal, date.description)
        defer {
            sign.end(Signs.fetchOrCreateJournal)
        }
        beamCheckMainThread()
        // Is the note in the cache?
        if let note = fetch(journalDate: date) {
            return note
        }

        // create a new note and add it to the cache
        return create(journalDate: date)
    }

    public static func availableTitle(withPrefix prefix: String) -> String {
        let documentManager = DocumentManager()
        let titles = documentManager.fetchAllNames(filters: [.titleMatch(prefix)])
        var availableTitle: String?
        var candidate = prefix
        var index = 1
        while availableTitle == nil {
            index += 1
            if titles.contains(candidate) {
                candidate = prefix + " \(index)"
            } else {
                availableTitle = candidate
            }
        }
        return availableTitle ?? prefix
    }

    public var lastChangedElement: BeamElement? {
        get {
            AppDelegate.main.data?.lastChangedElement
        }
        set {
            guard changePropagationEnabled else { return }
            AppDelegate.main.data?.lastChangedElement = newValue
        }
    }

    public static func updateNoteCount() {
        AppDelegate.main.data.updateNoteCount()
    }

    public var isTodaysNote: Bool { type.isJournal && type.journalDateString == BeamNoteType.iso8601ForDate(BeamDate.now) }

    public static func indexAllNotes() {
        let sign = Self.signPost.createId()
        sign.begin(Signs.indexAllNotes)
        defer {
            sign.end(Signs.indexAllNotes)
        }
        beamCheckMainThread()
        var log = [String]()
        log.append("Before reindexing, DB contains \((try? GRDBDatabase.shared.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? GRDBDatabase.shared.countIndexedElements()) ?? -1) indexed elements")
        try? GRDBDatabase.shared.clearElements()
        try? GRDBDatabase.shared.clearBidirectionalLinks()
        try? GRDBDatabase.shared.clearNoteIndexingRecord()
        let allIds = DocumentManager().allDocumentsIds(includeDeletedNotes: false)
        for id in allIds {
            if let note = BeamNote.fetch(id: id, includeDeleted: false) {
                note.indexContents()
            }
        }

        log.append("After reindexing \(allIds.count) notes, DB contains \((try? GRDBDatabase.shared.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? GRDBDatabase.shared.countIndexedElements()) ?? -1) indexed elements")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log.joined(separator: "\n"), forType: .string)
    }

    public static func rebuildAllNotes() {
        let sign = Self.signPost.createId()
        sign.begin(Signs.rebuildAllNotes)
        defer {
            sign.end(Signs.rebuildAllNotes)
        }
        beamCheckMainThread()
        let documentManager = DocumentManager()
        var rebuilt = [String]()
        for id in documentManager.allDocumentsIds(includeDeletedNotes: false) {
            if let note = BeamNote.fetch(id: id, includeDeleted: false) {
                _ = note.syncedSave()
                rebuilt.append("rebuilt note '\(note.title)' [\(note.id)]")
                rebuilt.append(contentsOf: note.validateLinks(fix: true))
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(rebuilt.joined(separator: "\n"), forType: .string)
    }

    public static func validateAllNotes() {
        beamCheckMainThread()
        let documentManager = DocumentManager()
        var all = [String]()
        for id in documentManager.allDocumentsIds(includeDeletedNotes: false) {
            if let note = BeamNote.fetch(id: id, includeDeleted: false) {
                let str = "validating \(note.title) - [\(note.id)]"
                all.append(str)
                //swiftlint:disable:next print
                print(str)
                let (success, msgs) = note.validate()
                if !success {
                    let str = "\tvalidation failed for note \(note.title) - \(note.id)"
                    //swiftlint:disable:next print
                    print(str)
                    all.append(str)
                    all.append(contentsOf: msgs)
                }
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let str = all.joined(separator: "\n")
        pasteboard.setString(str, forType: .string)
    }

    public func validate() -> (Bool, [String]) {
        beamCheckMainThread()
        guard let docStruct = documentStruct else {
            let str = "\tUnable to be documentStruct for note \(title) - \(id)"
            //swiftlint:disable:next print
            print(str)
            return (false, ["\tUnable to be documentStruct for note \(title) - \(id)"])
        }
        var validated = [String]()
        if docStruct.id != id {
            validated.append("\tdocumentStruct has wrong id \(docStruct.id)")
        }

        switch docStruct.documentType {
        case .journal:
            if !type.isJournal {
                validated.append("\tdocumentStruct has wrong type \(docStruct.documentType)")
            } else {
                if docStruct.journalDate == nil {
                    validated.append("\tdocumentStruct should have a journal_date but it hasn't")
                }
            }

        case .note:
            if type.isJournal {
                validated.append("\tdocumentStruct has wrong type \(docStruct.documentType)")
            }

            if let date = docStruct.journalDate {
                validated.append("\tdocumentStruct shouldn't have a journal_date but it has \(date)")
            }
        }

        validated.append(contentsOf: validateLinks(fix: false))
        //swiftlint:disable:next print
        print(validated.joined(separator: "\n"))
        return (true, validated)
    }

    public func validateLinks(fix: Bool) -> [String] {
        beamCheckMainThread()
        var strs = [String]()
        let documentManager = DocumentManager()
        let allDocuments = Set(documentManager.allDocumentsIds(includeDeletedNotes: false))

        for (elementId, text) in allTexts {
            for linkRange in text.internalLinkRanges {
                if let link = linkRange.internalLink {
                    if !allDocuments.contains(link) {
                        var msg = "Link from note '\(title)' [\(id) / \(elementId)] to '\(linkRange.string)' (\(link)) is invalid"
                        defer { strs.append(msg) }
                        if fix {
                            guard let element = findElement(elementId) else {
                                strs.append("Error, couldn't find element \(elementId) in note")
                                continue
                            }
                            element.text.removeAttributes([.internalLink(.null)], from: linkRange.range)
                            msg += " [fixed]"
                        }
                    } else {
                        strs.append("\t\t'\(title)' [\(elementId)] links to '\(linkRange.string)' (\(link))")
                    }
                }
            }
        }

        return strs
    }

    static public func loadNotes(_ ids: [UUID], _ completion: @escaping ([BeamNote]) -> Void) {
        let sign = Self.signPost.createId()
        sign.begin(Signs.loadNotes)
        DispatchQueue.global(qos: .userInitiated).async {
            completion(ids.compactMap { BeamNote.fetch(id: $0, includeDeleted: false, keepInMemory: true, decodeChildren: true) })
            sign.end(Signs.loadNotes)
        }
    }

    struct Signs {
        static let indexContents: StaticString = "indexContents"
        static let indexContentsReferences: StaticString = "indexContents.references"
        static let indexContentsLinks: StaticString = "indexContents.links"
        static let syncedSave: StaticString = "syncedSave"
        static let save: StaticString = "save"
        static let fetchTitle: StaticString = "fetchTitle"
        static let fetchJournalDate: StaticString = "fetchJournalDate"
        static let fetchId: StaticString = "fetchId"
        static let fetchNotesWithType: StaticString = "fetchNotesWithType"
        static let fetchJournalsFromDate: StaticString = "fetchJournalsFromDate"
        static let fetchJournalsBefore: StaticString = "fetchJournalsBefore"
        static let createTitle: StaticString = "createTitle"
        static let createJournalDate: StaticString = "createJournalDate"
        static let fetchOrCreate: StaticString = "fetchOrCreate"
        static let fetchOrCreateJournal: StaticString = "fetchOrCreateJournal"
        static let indexAllNotes: StaticString = "indexAllNotes"
        static let rebuildAllNotes: StaticString = "rebuildAllNotes"
        static let loadNotes: StaticString = "loadNotes"
    }

}
