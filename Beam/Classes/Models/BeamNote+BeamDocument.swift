//
//  BeamNote+BeamDocument.swift
//  Beam
//
//  Created by Sebastien Metrot on 02/06/2022.
//

import Foundation
import BeamCore

struct NullDocumentSource: BeamDocumentSource {
    static var sourceId: String { "" }
}

public extension BeamNote {
    var document: BeamDocument? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(self)
            #if DEBUG
            // an empty BeamNote encoded to JSon is at lease 250 bytes
            assert(data.count > 250, "data should encode a full note, it shouldn't be empty (trying to create a beam document out of \(self)")
            #endif
            guard var doc = documentLight else { return nil }
            doc.data = data
            return doc
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }

    /// This version of DocumentStruct doesn't contain the encoded data. If must only be used for observing task
    var documentLight: BeamDocument? {
        if database == nil {
            Logger.shared.logError("Database should already have been set", category: .document)
        }

        return BeamDocument(id: id,
                            source: NullDocumentSource(),
                            database: database,
                            title: title,
                            createdAt: creationDate,
                            updatedAt: updateDate,
                            data: Data(),
                            documentType: DocumentType(from: type),
                            version: version,
                            isPublic: publicationStatus.isPublic,
                            journalDate: JournalDateConverter.toInt(from: type.journalDateString ?? "0"),
                            tabGroupId: type.tabGroupId
        )
    }

    static func instanciateNote(_ document: BeamDocument,
                                keepInMemory: Bool = true,
                                decodeChildren: Bool = true) throws -> BeamNote {

        let decoder = BeamJSONDecoder()
        if decodeChildren == false {
            decoder.userInfo[BeamElement.recursiveCoding] = false
        }
        let note = try decoder.decode(BeamNote.self, from: document.data)
        note.version = document.version
        note.owner = document.database
        note.updateDate = document.updatedAt

        if keepInMemory {
            appendToFetchedNotes(note)
        }
        return note
    }

    var database: BeamDatabase? {
        owner as? BeamDatabase
    }

    static var defaultCollection: BeamDocumentCollection? { BeamData.shared.currentDocumentCollection
    }

    private var noteLinksAndRefsManager: BeamNoteLinksAndRefsManager? {
        BeamData.shared.noteLinksAndRefsManager
    }

    static var purgingNotes = Set<UUID>()
    static func updateNote(_ source: BeamDocumentSource, _ document: BeamDocument) {
        guard document.deletedAt == nil else {
            purgeDeletedNode(source, document.id)
            return
        }

        guard let note = Self.getFetchedNote(document.id) else {
            return
        }

        note.updateAttempts += 1
        /*
         When receiving updates for a new document, we don't check the version
         */
        if document.source == NoteAutoSaveService.sourceId {
            Logger.shared.logDebug("\(note.titleAndId) observer skipped, source is \(document.source) (must not be \(NoteAutoSaveService.sourceId))",
                                   category: .documentNotification)
            return
        }
        if document.version <= note.version, note.id == document.id {
            Logger.shared.logDebug("\(note.titleAndId) observer skipped \(document.version) (must be > \(note.version)",
                                   category: .documentNotification)
            return
        }

        note.changePropagationEnabled = false
        defer {
            note.changePropagationEnabled = true
        }

        Logger.shared.logDebug("updateNote received for \(document.titleAndId)",
                               category: .documentNotification)

        note.updateWithDocument(document)
    }
    static func purgeDeletedNode(_ source: BeamDocumentSource, _ id: UUID) {
        beamCheckMainThread()
        guard let note = Self.getFetchedNote(id) else {
            return
        }

        unload(note: note)

        note.links.map({ $0.noteID }).forEach { id in
            guard let note = BeamNote.fetch(id: id, keepInMemory: false) else { return }
            note.recursiveChangePropagationEnabled = false
            note.updateNoteNamesInInternalLinks(recursive: true)
            _ = note.save(source)
            note.recursiveChangePropagationEnabled = true
        }

        do {
            try BeamData.shared.noteLinksAndRefsManager?.remove(noteId: note.id)
        } catch {
            Logger.shared.logError("Impossible to remove all notes from indexing: \(error)", category: .search)
        }
    }

    func updateWithDocument(_ document: BeamDocument, file: StaticString = #file, line: UInt = #line) {
        beamCheckMainThread()
        let context = "file: \(file):\(line)"
        if document.version <= self.version , self.id == document.id {
            Logger.shared.logDebug("\(self.titleAndId) update skipped \(document.version) (must be > \(self.version)) [caller: \(context)]",
                                   category: .document)
            return
        }

        self.updates += 1
        let decoder = BeamJSONDecoder()
        guard let newSelf = try? decoder.decode(BeamNote.self, from: document.data) else {
            Logger.shared.logError("Unable to decode new document \(document.title) {\(document.id)} [caller: \(context)]",
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

        self.version = document.version
        self.owner = document.database

        Logger.shared.logDebug("updateWithDocument updating \(title) - \(id) [caller: \(context)]", category: .document)
        recursiveUpdate(other: newSelf)
    }

    func updateTitle(_ source: BeamDocumentSource, _ newTitle: String) {
        beamCheckMainThread()
        let previousTitle = self.title
        try? noteLinksAndRefsManager?.remove(note: self)
        self.title = newTitle
        if getFetchedNote(self.id) != nil {
            // Only reload the note if it was already loaded
            Self.reloadAfterRename(previousTitle: previousTitle, note: self)
        }
        indexContents()
        Logger.shared.logInfo("Rename \(previousTitle) to \(title) [\(id)]", category: .document)
//        BeamData.shared.renamedNote = (id, previousTitle, title)

        _ = save(source)

        for link in links {
            guard let element = link.element else { continue }
            element.updateNoteNamesInInternalLinks(recursive: true)
            _ = element.note?.save(source)
        }
    }

    static func updateTitleLocally(_ source: BeamDocumentSource, id: UUID, _ newTitle: String) {
        beamCheckMainThread()
        guard let previousTitle = BeamNote.titleForNoteId(id) else { return }
        try? BeamData.shared.noteLinksAndRefsManager?.remove(noteId: id)
        if let note = getFetchedNote(id) {
            // Only reload the note if it was already loaded
            Self.reloadAfterRename(previousTitle: previousTitle, note: note)
        }
        Logger.shared.logInfo("Rename \(previousTitle) to \(newTitle) [\(id)]", category: .document)

        let links = (try? BeamData.shared.noteLinksAndRefsManager?.fetchLinks(toNote: id).map({ bidiLink in
            BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
        })) ?? []

        for link in links {
            guard let element = link.element else { continue }
            element.updateNoteNamesInInternalLinks(recursive: true)
            _ = element.note?.save(source)
        }
    }

    func indexContents() {
        beamCheckMainThread()
        sign.begin(Signs.indexContents, titleAndId)
        try? noteLinksAndRefsManager?.append(note: self)
        sign.end(Signs.indexContents)
    }

    func save(_ source: BeamDocumentSource, autoIncrementVersion: Bool = true) -> Bool {
        let originalVersion = version
        if autoIncrementVersion {
            version = originalVersion.incremented()
        }

        guard let document = document,
              let collection = document.collection
        else {
            version = originalVersion
            return false
        }

        sign.begin(Signs.save, titleAndId)
        do {
            _ = try collection.save(source, document, indexDocument: false, autoIncrementVersion: false)
            indexContents()
        } catch {
            Logger.shared.logError("Failed to save note \(self): \(error)", category: .document)
            version = originalVersion
            return false
        }

        self.recalculateFileReferences()

        sign.end(Signs.save)
        return true
    }

    func recalculateFileReferences() {
        guard let fileDBManager = self.database?.fileDBManager else { return }

        // remove all file references:
        do {
            try fileDBManager.removeReference(fromNote: self.id, element: nil)
            // and recreate them:
            for fileElement in self.allFileElements {
                try fileDBManager.addReference(fromNote: self.id, element: fileElement.1.id, to: fileElement.0)
            }
        } catch {
            Logger.shared.logError("Error while updating file references for note \(self.titleAndId)", category: .document)
        }
    }

    static func instanciateNoteWithPreviousData(_ document: BeamDocument,
                                                decodeChildren: Bool = true) throws -> BeamNote? {
        let decoder = BeamJSONDecoder()
        if decodeChildren == false {
            decoder.userInfo[BeamElement.recursiveCoding] = false
        }

        guard let previousData = BeamObjectChecksum.sentData(object: document) else { return nil }

        let note = try decoder.decode(BeamNote.self, from: previousData)
        note.version = document.version
        note.owner = document.database
        note.updateDate = document.updatedAt

        return note
    }

    static func fetch(title: String,
                      keepInMemory: Bool = true,
                      decodeChildren: Bool = true) -> BeamNote? {
        guard let collection = Self.defaultCollection else { return nil }
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchTitle, title)
        defer {
            sign.end(Signs.fetchTitle)
        }

        // Is the note in the cache?
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        do {
            guard let doc = try collection.fetchFirst(filters: [.title(title)]) else {
                return nil
            }

            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to fetch or decode note titled \(title): \(error)", category: .document)
        }

        return nil
    }

    static func fetch(journalDate: Date,
                      keepInMemory: Bool = true,
                      decodeChildren: Bool = true) -> BeamNote? {
        guard let collection = Self.defaultCollection else { return nil }
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalDate, journalDate.description)
        defer {
            sign.end(Signs.fetchJournalDate)
        }
        // Is the note in the cache?
        let title = BeamDate.journalNoteTitle(for: journalDate)
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        do {
            guard let doc = try collection.fetchFirst(filters: [.journalDate(BeamNoteType.intFrom(journalDate: journalDate))]) else {
                return nil
            }

        //        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to fetch or decode journal note for date \(journalDate))", category: .document)
        }

        return nil
    }

    static func fetch(tabGroupId: UUID,
                      keepInMemory: Bool = true,
                      decodeChildren: Bool = true) -> BeamNote? {
        guard let collection = Self.defaultCollection else { return nil }
        beamCheckMainThread()
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchTabGroupNote, tabGroupId.uuidString)
        defer {
            sign.end(Signs.fetchTabGroupNote)
        }
        // Is the note in the cache?
        if let note = getFetchedNote(tabGroupId: tabGroupId) {
            return note
        }

        // Is the note in the document store?
        do {
            guard let doc = try collection.fetchFirst(filters: [.tabGroups([tabGroupId])]) else {
                return nil
            }
            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to fetch or decode tab group note for id \(tabGroupId))", category: .document)
        }

        return nil
    }

    static func fetch(id: UUID,
                      keepInMemory: Bool = true, fetchFromMemory: Bool = true,
                      decodeChildren: Bool = true, verifyDatabase: Bool = true) -> BeamNote? {
        guard let collection = Self.defaultCollection else { return nil }
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchId, id.uuidString)
        defer {
            sign.end(Signs.fetchId)
        }

        if keepInMemory || fetchFromMemory {
            // Is the note in the cache?
            if let note = getFetchedNote(id) {
                return note
            }
        }

        // Is the note in the document store?
        do {
            guard let doc = try collection.fetchFirst(filters: [.id(id)]) else {
                return nil
            }

            return try instanciateNote(doc, keepInMemory: keepInMemory, decodeChildren: decodeChildren)
        } catch {
            Logger.shared.logError("Unable to decode note \(id): \(error)", category: .document)
        }

        return nil
    }

    static func fetchJournalsFrom(date: String) -> [BeamNote] {
        beamCheckMainThread()
        guard let collection = Self.defaultCollection else { return [] }
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalsFromDate, date)
        defer {
            sign.end(Signs.fetchJournalsFromDate)
        }

        do {
            let todayInt = JournalDateConverter.toInt(from: date)

            return try collection.fetch(filters: [.type(.journal), .nonFutureJournalDate(todayInt)], sortingKey: .journal(false)).compactMap({ Self.fetch(id: $0.id) })
        } catch { return [] }
    }

    static func fetchJournalsBefore(count: Int, date: String) -> [BeamNote] {
        beamCheckMainThread()
        guard let collection = Self.defaultCollection else { return [] }
        let sign = Self.signPost.createId()
        sign.begin(Signs.fetchJournalsBefore, date)
        defer {
            sign.end(Signs.fetchJournalsBefore)
        }
        do {
            let dateInt = JournalDateConverter.toInt(from: date)

            return try collection.fetch(filters: [.type(.journal), .beforeJournalDate(dateInt), .limit(count, offset: nil)], sortingKey: .journal(false)).compactMap({ Self.fetch(id: $0.id) })
        } catch { return [] }
    }

    static private func insertDefaultFrecency(noteId: UUID) {
        BeamData.shared.noteFrecencyScorer.update(id: noteId, value: 1.0, eventType: .noteCreate, date: BeamDate.now, paramKey: .note30d0)
        BeamData.shared.noteFrecencyScorer.update(id: noteId, value: 1.0, eventType: .noteCreate, date: BeamDate.now, paramKey: .note30d1)
    }

    static func fetchOrCreate(_ source: BeamDocumentSource, title: String) throws -> BeamNote {
        beamCheckMainThread()
        guard !Self.validTitle(fromTitle: title).isEmpty else { throw BeamNoteError.invalidTitle }

        if let note = getFetchedNote(title) {
            return note
        }

        let sign = Self.signPost.createId()
        sign.begin(Signs.createTitle, title)
        defer {
            sign.end(Signs.createTitle)
        }
        return try fetchOrCreate(source, type: .note(title: title))
    }

    static func fetchOrCreateJournalNote(_ source: BeamDocumentSource, date: Date) throws -> BeamNote {
        beamCheckMainThread()

        if let note = getFetchedNote(date) {
            return note
        }

        let sign = Self.signPost.createId()
        sign.begin(Signs.createJournalDate, date.description)
        defer {
            sign.end(Signs.createJournalDate)
        }
        return try fetchOrCreate(source, type: .journal(date: date))
    }

    static func fetchOrCreate(_ source: BeamDocumentSource, tabGroupId: UUID) throws -> BeamNote {
        beamCheckMainThread()

        if let note = getFetchedNote(tabGroupId: tabGroupId) {
            return note
        }

        let sign = Self.signPost.createId()
        sign.begin(Signs.createTabGroupNote, tabGroupId.description)
        defer {
            sign.end(Signs.createTabGroupNote)
        }
        return try fetchOrCreate(source, type: .tabGroup(tabGroupId: tabGroupId))
    }

    private static func fetchOrCreate(_ source: BeamDocumentSource, type: BeamDocumentCollection.CreationType) throws -> BeamNote {
        beamCheckMainThread()
        guard let collection = Self.defaultCollection else { throw BeamNoteError.noDefaultCollection }

        let document = try collection.fetchOrCreate(source, type: type)
        let note = try instanciateNote(document, keepInMemory: true, decodeChildren: true)

        Self.insertDefaultFrecency(noteId: note.id)
        return note
    }

    static func availableTitle(withPrefix prefix: String) -> String {
        guard let collection = defaultCollection else { return prefix + " bis" }
        let titles = (try? collection.fetchTitles(filters: [.titleMatch(prefix)])) ?? []
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

    static func updateNoteCount() {
        BeamData.shared.updateNoteCount()
    }

    var isTodaysNote: Bool { type.isJournal && type.journalDateString == BeamNoteType.iso8601ForDate(BeamDate.now) }

    static func indexAllNotes(interactive: Bool) {
        let sign = Self.signPost.createId()
        sign.begin(Signs.indexAllNotes)
        defer {
            sign.end(Signs.indexAllNotes)
        }
        beamCheckMainThread()
        var log = [String]()
        log.append("Before reindexing, DB contains \((try? BeamData.shared.noteLinksAndRefsManager?.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) ?? -1) indexed elements")
        try? BeamData.shared.noteLinksAndRefsManager?.clearElements()
        try? BeamData.shared.noteLinksAndRefsManager?.clearBidirectionalLinks()
        try? BeamData.shared.noteLinksAndRefsManager?.clearNoteIndexingRecord()
        let allIds = (try? BeamData.shared.currentDocumentCollection?.fetchIds(filters: [])) ?? []
        for id in allIds {
            if let note = BeamNote.fetch(id: id) {
                note.indexContents()
            }
        }

        log.append("After reindexing \(allIds.count) notes, DB contains \((try? BeamData.shared.noteLinksAndRefsManager?.countBidirectionalLinks()) ?? -1) bidirectional links from \((try? BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) ?? -1) indexed elements")

        if interactive {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(log.joined(separator: "\n"), forType: .string)
        }
    }

    static func rebuildAllNotes(_ source: BeamDocumentSource, interactive: Bool) throws {
        beamCheckMainThread()
        guard let collection = defaultCollection else { return  }
        let sign = Self.signPost.createId()
        sign.begin(Signs.rebuildAllNotes)
        defer {
            sign.end(Signs.rebuildAllNotes)
        }
        var rebuilt = [String]()
        for id in try collection.fetchIds(filters: []) {
            if let note = BeamNote.fetch(id: id) {
                _ = note.save(source)
                rebuilt.append("rebuilt note '\(note.title)' [\(note.id)]")
                rebuilt.append(contentsOf: try note.validateLinks(fix: true))
            }
        }

        if interactive {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(rebuilt.joined(separator: "\n"), forType: .string)
        }
    }

    static func validateAllNotes(interactive: Bool) throws {
        guard let collection = defaultCollection else { return  }
        beamCheckMainThread()
        var all = [String]()
        for id in try collection.fetchIds(filters: []) {
            if let note = BeamNote.fetch(id: id) {
                let str = "validating \(note.title) - [\(note.id)]"
                all.append(str)
                print(str)
                let (success, msgs) = try note.validate()
                if !success {
                    let str = "\tvalidation failed for note \(note.title) - \(note.id)"
                    print(str)
                    all.append(str)
                    all.append(contentsOf: msgs)
                }
            }
        }

        if interactive {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let str = all.joined(separator: "\n")
            pasteboard.setString(str, forType: .string)
        }
    }

    func validate() throws -> (Bool, [String]) {
        beamCheckMainThread()
        guard let document = self.document else {
            let str = "\tUnable to be documentStruct for note \(title) - \(id)"
            print(str)
            return (false, ["\tUnable to be documentStruct for note \(title) - \(id)"])
        }
        var validated = [String]()
        if document.id != id {
            validated.append("\tdocumentStruct has wrong id \(document.id)")
        }

        switch document.documentType {
        case .journal:
            if !type.isJournal {
                validated.append("\tdocumentStruct has wrong type \(document.documentType)")
            } else {
                if document.journalDate == 0 {
                    validated.append("\tdocumentStruct should have a journal_date but it hasn't")
                }
            }
        case .tabGroup:
            if !type.isTabGroup {
                validated.append("\tdocumentStruct has wrong type \(document.documentType)")
            } else {
                if document.tabGroupId == nil {
                    validated.append("\tdocumentStruct should have a tabGroupId but it hasn't")
                }
            }
        case .note:
            if type.isJournal {
                validated.append("\tdocumentStruct has wrong type \(document.documentType)")
            }

            if document.journalDate != 0 {
                validated.append("\tdocumentStruct shouldn't have a journal_date but it has \(document.journalDate)")
            }
            if let tabGroupId = document.tabGroupId {
                validated.append("\tdocumentStruct shouldn't have a tabGroupId but it has \(tabGroupId)")
            }
        }

        validated.append(contentsOf: try validateLinks(fix: false))
        print(validated.joined(separator: "\n"))
        return (true, validated)
    }

    func validateLinks(fix: Bool) throws -> [String] {
        guard let collection = BeamNote.defaultCollection else { throw BeamNoteError.noDefaultCollection }
        beamCheckMainThread()
        var strs = [String]()
        let allDocuments = Set(try collection.fetchIds(filters: []))

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

    static func loadNotes(_ ids: [UUID], _ completion: @escaping ([BeamNote]) -> Void) {
        let sign = Self.signPost.createId()
        sign.begin(Signs.loadNotes)
        DispatchQueue.userInitiated.async {
            completion(ids.compactMap { BeamNote.fetch(id: $0, keepInMemory: true, decodeChildren: true) })
            sign.end(Signs.loadNotes)
        }
    }

    struct Signs {
        static let indexContents: StaticString = "indexContents"
        static let indexContentsReferences: StaticString = "indexContents.references"
        static let indexContentsLinks: StaticString = "indexContents.links"
        static let save: StaticString = "save"
        static let syncedSave: StaticString = "syncedSave"
        static let fetchTitle: StaticString = "fetchTitle"
        static let fetchJournalDate: StaticString = "fetchJournalDate"
        static let fetchTabGroupNote: StaticString = "fetchTabGroupNote"
        static let fetchId: StaticString = "fetchId"
        static let fetchNotesWithType: StaticString = "fetchNotesWithType"
        static let fetchJournalsFromDate: StaticString = "fetchJournalsFromDate"
        static let fetchJournalsBefore: StaticString = "fetchJournalsBefore"
        static let createTitle: StaticString = "createTitle"
        static let createJournalDate: StaticString = "createJournalDate"
        static let createTabGroupNote: StaticString = "createTabGroupNote"
        static let fetchOrCreate: StaticString = "fetchOrCreate"
        static let fetchOrCreateJournal: StaticString = "fetchOrCreateJournal"
        static let indexAllNotes: StaticString = "indexAllNotes"
        static let rebuildAllNotes: StaticString = "rebuildAllNotes"
        static let loadNotes: StaticString = "loadNotes"
    }
}

public extension BeamDocument {
    func previousTextDescription() throws -> String? {
        if let beamNote = try BeamNote.instanciateNoteWithPreviousData(self, decodeChildren: true) {
            return beamNote.textDescription()
        }
        return nil
    }
}

extension BeamNote: BeamNoteDocument {
    public var lastChangedElement: BeamElement? {
        get {
            var element: BeamElement?
            DispatchQueue.mainSync {
                element = BeamData.shared?.lastChangedElement
            }
            return element
        }
        set {
            guard changePropagationEnabled else { return }
            DispatchQueue.main.async {
                BeamData.shared?.lastChangedElement = newValue
            }
        }
    }

    public func autoSave() {
        beamCheckMainThread()
        BeamData.shared.noteAutoSaveService.addNoteToSave(self)
    }
}
