//
//  BeamNote+DocumentManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//
//swiftlint:disable file_length

import Foundation
import BeamCore

extension BeamNote: BeamNoteDocument {
    var documentStruct: DocumentStruct? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(self)

            if databaseId == nil {
                Logger.shared.logError("DatabaseID should already have been set", category: .document)
            }

            let structDBId = databaseId ?? DatabaseManager.defaultDatabase.id

            return DocumentStruct(id: id,
                                  databaseId: structDBId,
                                  title: title,
                                  createdAt: creationDate,
                                  updatedAt: updateDate,
                                  data: data,
                                  documentType: type.isJournal ? .journal : .note,
                                  version: version,
                                  isPublic: publicationStatus.isPublic,
                                  journalDate: type.journalDateString)
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }

    public func observeDocumentChange(documentManager: DocumentManager) {
        beamCheckMainThread()
        guard activeDocumentCancellables.isEmpty else {
            Logger.shared.logError("BeamNote already has change observer", category: .document)
            return
        }
        guard let docStruct = documentStruct else { return }

        Logger.shared.logInfo("Observe changes for note \(titleAndId)", category: .document)
        activeDocumentCancellables = []
        activeDocumentCancellables.append(documentManager.onDocumentChange(docStruct) { [unowned self] doc in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                /*
                 When receiving updates for a new document, we don't check the version
                 */
                if self.version >= doc.version, self.id == doc.id {
                    Logger.shared.logDebug("BeamNote \(self.titleAndId) observer skipped \(doc.titleAndId) (must be greater than current \(self.version))")
                    return
                }

                changePropagationEnabled = false
                defer {
                    changePropagationEnabled = true
                }

                updateWithDocumentStruct(doc)
            }
        })

        activeDocumentCancellables.append(documentManager.onDocumentDelete(docStruct) { [unowned self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.deleted = true
                Self.unload(note: self)
                for note in Self.fetchedNotes {
                    note.value.ref?.updateNoteNamesInInternalLinks(recursive: true)
                }

            }
        })
    }

    func updateWithDocumentStruct(_ docStruct: DocumentStruct) {
        beamCheckMainThread()
        let decoder = JSONDecoder()
        guard let newSelf = try? decoder.decode(BeamNote.self, from: docStruct.data) else {
            Logger.shared.logError("Unable to decode new documentStruct \(docStruct.title) {\(docStruct.id)}",
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
        self.browsingSessions = newSelf.browsingSessions

        self.version = docStruct.version
        self.databaseId = docStruct.databaseId
        self.deleted = docStruct.deletedAt != nil

        self.savedVersion = self.version

        recursiveUpdate(other: newSelf)
    }

    public func updateTitle(_ newTitle: String, documentManager: DocumentManager) {
        beamCheckMainThread()
        let previousTitle = self.title
        try? GRDBDatabase.shared.remove(note: self)
        self.title = newTitle
        Self.reloadAfterRename(previousTitle: previousTitle, note: self)
        indexContents()
        Logger.shared.logInfo("Rename \(previousTitle) to \(title) [\(id)]", category: .document)
        AppDelegate.main.data.renamedNote = (id, previousTitle, title)
    }

    public func indexContents() {
        beamCheckMainThread()
        try? GRDBDatabase.shared.append(note: self)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        beamCheckMainThread()
        guard version == savedVersion else {
            Logger.shared.logWarning("Waiting for last save: \(title) {\(id)} - saved version \(savedVersion) / current \(version)",
                                     category: .document)
            completion?(.failure(BeamNoteError.saveAlreadyRunning))
            return
        }

        /*
         When saving the note, we must increment its version first. `documentManager.save()` will check for
         version increase between saves.
         */

        version += 1

        guard let documentStruct = documentStruct else {
            version -= 1
            Logger.shared.logError("Unable to find active document struct \(titleAndId)", category: .document)
            completion?(.failure(BeamNoteError.unableToCreateDocumentStruct))
            return
        }

        // Index saved notes:
        indexContents()

        Logger.shared.logInfo("BeamNote wants to save: \(titleAndId)", category: .document)
        documentManager.save(documentStruct, completion: { [weak self] result in
            guard let self = self else { completion?(result); return }

            switch result {
            case .success(let success):
                guard success else { break }
                // TSAN: We need to sync dispatch it to the main thread to make sure it doesn't create a data race.
                DispatchQueue.main.async {
                    self.savedVersion = self.version
                    self.pendingSave = 0
                }

            case .failure(BeamNoteError.saveAlreadyRunning):
                DispatchQueue.main.async {
                    self.pendingSave += 1
                }

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

                        if let dbDocumentStruct = documentManager.loadById(id: documentStruct.id) {
                            DispatchQueue.main.async {
                                self.updateWithDocumentStruct(dbDocumentStruct)
                            }
                        }

                        Logger.shared.logError("Version changed to \(self.savedVersion)/\(self.version)",
                                               category: .document)
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
                            documentManager.delete(id: documentStruct.id) { _ in
                                DispatchQueue.main.sync {
                                    self.updateWithDocumentStruct(existingDocument)
                                    self.savedVersion = existingDocument.version
                                }

                                completion?(result)
                            }

                            // Avoid calling save() again
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

                        completion?(.failure(error))
                        return
                    default:
                        Logger.shared.logError("Error saving: \(error.localizedDescription)",
                                               category: .document)
                    }
                }

                DispatchQueue.main.async {
                    self.version = self.savedVersion
                }
                Logger.shared.logError("Saving note \(self.titleAndId) failed: \(error)", category: .document)

                if self.pendingSave > 0 {
                    Logger.shared.logDebug("Trying again: Saving note \(self.titleAndId) as there were \(self.pendingSave) pending save operations",
                                           category: .document)
                    self.save(documentManager: documentManager, completion: completion)
                }
            }

            completion?(result)
        })
    }

    static func instanciateNote(_ documentStruct: DocumentStruct,
                                keepInMemory: Bool = true,
                                decodeChildren: Bool = true) throws -> BeamNote {
        let decoder = JSONDecoder()
        if decodeChildren == false {
            decoder.userInfo[BeamElement.recursiveCoding] = false
        }
        let note = try decoder.decode(BeamNote.self, from: documentStruct.data)
        note.version = documentStruct.version
        note.databaseId = documentStruct.databaseId
        note.savedVersion = note.version
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
        if let previousData = documentStruct.previousData {
            let note = try decoder.decode(BeamNote.self, from: previousData)
            note.version = documentStruct.version
            note.databaseId = documentStruct.databaseId
            note.savedVersion = note.version
            note.updateDate = documentStruct.updatedAt
            note.deleted = documentStruct.deletedAt != nil

            return note
        }
        return nil
    }

    public static func fetch(_ documentManager: DocumentManager,
                             title: String,
                             keepInMemory: Bool = true,
                             decodeChildren: Bool = true) -> BeamNote? {
        beamCheckMainThread()
        // Is the note in the cache?
        if let note = getFetchedNote(title) {
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

    public static func fetch(_ documentManager: DocumentManager,
                             journalDate: Date,
                             keepInMemory: Bool = true,
                             decodeChildren: Bool = true) -> BeamNote? {
        beamCheckMainThread()
        // Is the note in the cache?
        let title = BeamDate.journalNoteTitle(for: journalDate)
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentWithJournalDate(BeamNoteType.iso8601ForDate(journalDate)) else {
            return nil
        }

        // HOTFIX: remove empty notes that were errounously saved
        guard !doc.data.isEmpty else {
            Logger.shared.logError("HOTFIX - Data for note \(doc.title) (\(doc.id)) is empty -> deleting the note from the DB", category: .document)
            do {
                try documentManager.delete([doc.id])
            } catch {
                Logger.shared.logError("HOTFIX - Error while deleting \(doc.title) (\(doc.id))", category: .document)
            }
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

    public static func fetch(_ documentManager: DocumentManager,
                             id: UUID,
                             keepInMemory: Bool = true,
                             decodeChildren: Bool = true) -> BeamNote? {
        if keepInMemory {
            beamCheckMainThread()
            // Is the note in the cache?
            if let note = getFetchedNote(id) {
                return note
            }
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentById(id: id) else {
            return nil
        }

        do {
            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetchNotesWithType(_ documentManager: DocumentManager, type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [BeamNote] {
        beamCheckMainThread()
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

    // Beware that this function crashes whatever note with that title in the cache
    public static func create(_ documentManager: DocumentManager, title: String) -> BeamNote {
        beamCheckMainThread()
        assert(getFetchedNote(title) == nil)
        let note = BeamNote(title: title)
        note.databaseId = DatabaseManager.defaultDatabase.id

        appendToFetchedNotes(note)
        updateNoteCount()
        note.save(documentManager: documentManager)
        return note
    }

    public static func create(_ documentManager: DocumentManager, journalDate: Date) -> BeamNote {
        beamCheckMainThread()
        let note = BeamNote(journalDate: journalDate)
        note.databaseId = DatabaseManager.defaultDatabase.id

        // TODO: should force a first quick save to trigger any title conflicts with the API asap
        appendToFetchedNotes(note)
        updateNoteCount()
        note.save(documentManager: documentManager)
        return note
    }

    public func observeDocumentChange() {
        beamCheckMainThread()
        observeDocumentChange(documentManager: AppDelegate.main.data.documentManager)
    }

    public func autoSave() {
        beamCheckMainThread()
        AppDelegate.main.data.noteAutoSaveService.addNoteToSave(self)
    }

    public static func fetchOrCreate(_ documentManager: DocumentManager, title: String) -> BeamNote {
        beamCheckMainThread()
        // Is the note in the cache?
        if let note = fetch(documentManager, title: title) {
            return note
        }

        // create a new note and add it to the cache
        return create(documentManager, title: title)
    }

    public static func fetchOrCreateJournalNote(_ documentManager: DocumentManager, date: Date) -> BeamNote {
        beamCheckMainThread()
        // Is the note in the cache?
        if let note = fetch(documentManager, journalDate: date) {
            return note
        }

        // create a new note and add it to the cache
        return create(documentManager, journalDate: date)
    }

    public var lastChangedElement: BeamElement? {
        get {
            AppDelegate.main.data.lastChangedElement
        }
        set {
            AppDelegate.main.data.lastChangedElement = newValue
        }
    }

    public static func updateNoteCount() {
        AppDelegate.main.data.updateNoteCount()
    }

    public var isTodaysNote: Bool { type.isJournal && type.journalDateString == BeamNoteType.iso8601ForDate(BeamDate.now) }

    public static func indexAllNotes() {
        beamCheckMainThread()
        let documentManager = DocumentManager()
        var log = [String]()
        log.append("Before reindexing, DB contains \((try? GRDBDatabase.shared.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? GRDBDatabase.shared.countIndexedElements()) ?? -1) indexed elements")
        try? GRDBDatabase.shared.clearElements()
        try? GRDBDatabase.shared.clearBidirectionalLinks()
        try? GRDBDatabase.shared.clearNoteIndexingRecord()
        let allTitles = documentManager.allDocumentsTitles(includeDeletedNotes: false)
        for title in allTitles {
            if let note = BeamNote.fetch(documentManager, title: title) {
                note.indexContents()
            }
        }

        log.append("After reindexing \(allTitles.count) notes, DB contains \((try? GRDBDatabase.shared.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? GRDBDatabase.shared.countIndexedElements()) ?? -1) indexed elements")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log.joined(separator: "\n"), forType: .string)
    }

    public static func rebuildAllNotes() {
        beamCheckMainThread()
        let documentManager = DocumentManager()
        var rebuilt = [String]()
        for id in documentManager.allDocumentsIds(includeDeletedNotes: false) {
            if let note = BeamNote.fetch(documentManager, id: id) {
                note.save(documentManager: documentManager)
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
            if let note = BeamNote.fetch(documentManager, id: id) {
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
}
