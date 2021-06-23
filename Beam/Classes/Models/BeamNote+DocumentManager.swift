//
//  BeamNote+DocumentManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation
import BeamCore

extension BeamNote: BeamNoteDocument {
    public var documentStruct: DocumentStruct? {
        do {
            let encoder = JSONEncoder()
            // Will make conflict and merge easier to know what lines conflicted instead
            // of having all content on a single line to save space
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)

            return DocumentStruct(id: id,
                                  databaseId: databaseId ?? DatabaseManager.defaultDatabase.id,
                                  title: title,
                                  createdAt: creationDate,
                                  updatedAt: updateDate,
                                  data: data,
                                  documentType: type == .journal ? .journal : .note,
                                  version: version,
                                  isPublic: isPublic)
        } catch {
            Logger.shared.logError("Unable to encode BeamNote into DocumentStruct [\(title) {\(id)}]", category: .document)
            return nil
        }
    }

    public func observeDocumentChange(documentManager: DocumentManager) {
        guard activeDocumentCancellable == nil else { return }
        guard let docStruct = documentStruct else { return }

        Logger.shared.logInfo("Observe changes for note \(title)", category: .document)
        activeDocumentCancellable = documentManager.onDocumentChange(docStruct) { [unowned self] docStruct in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                guard self.version < docStruct.version else {
                    Logger.shared.logDebug("BeamNote \(self.title) observer skipped version \(docStruct.version) (must be greater than current \(self.version))")
                    return
                }

                changePropagationEnabled = false
                defer {
                    changePropagationEnabled = true
                }

                updateWithDocumentStruct(docStruct)
            }
        }
    }

    public func updateWithDocumentStruct(_ docStruct: DocumentStruct) {
        let decoder = JSONDecoder()
        guard let newSelf = try? decoder.decode(BeamNote.self, from: docStruct.data) else {
            Logger.shared.logError("Unable to decode new documentStruct \(docStruct.title)",
                                   category: .document)
            return
        }

        self.title = newSelf.title
        self.type = newSelf.type
        self.searchQueries = newSelf.searchQueries
        self.visitedSearchResults = newSelf.visitedSearchResults
        self.browsingSessions = newSelf.browsingSessions

        self.version = docStruct.version
        self.databaseId = docStruct.databaseId
        self.isPublic = docStruct.isPublic

        self.savedVersion = self.version

        recursiveUpdate(other: newSelf)
    }

    public func updateTitle(_ newTitle: String, documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        let previousTitle = self.title
        try? GRDBDatabase.shared.remove(note: self)
        Self.unload(note: self)
        self.title = newTitle
        self.save(documentManager: documentManager) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                try? GRDBDatabase.shared.append(note: self)
                Self.appendToFetchedNotes(self)
            }

            completion?(result)
        }
    }

    public func save(documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard version == savedVersion else {
            Logger.shared.logError("Waiting for last save [\(title) {\(id)} - saved version \(savedVersion) / current \(version)]",
                                   category: .document)
            completion?(.failure(BeamNoteError.saveAlreadyRunning))
            return
        }

        version += 1

        guard let documentStruct = documentStruct else {
            version -= 1
            Logger.shared.logError("Unable to find active document struct [\(title) {\(id)}]", category: .document)
            completion?(.failure(BeamNoteError.unableToCreateDocumentStruct))
            return
        }

        Logger.shared.logInfo("BeamNote wants to save: \(title) version \(version)", category: .document)
        documentManager.save(documentStruct, completion: { [weak self] result in
            guard let self = self else { completion?(result); return }

            switch result {
            case .success(let success):
                guard success else { break }
                self.savedVersion = self.version
                self.pendingSave = 0

            case .failure(BeamNoteError.saveAlreadyRunning):
                self.pendingSave += 1

            case .failure(let error):
                if (error as NSError).domain == "DOCUMENT_ERROR_DOMAIN", (error as NSError).code == 1002 {
                    Logger.shared.logError("Version error with \(self.version), reloading from the DB", category: .document)

                    // TODO: should merge the change we tried to save(), with the DB version instead of just reloading it
                    if let dbDocumentStruct = documentManager.loadById(id: documentStruct.id) {
                        DispatchQueue.main.async {
                            self.updateWithDocumentStruct(dbDocumentStruct)
                        }
                    }

                    Logger.shared.logError("Version changed to \(self.savedVersion)/\(self.version)", category: .document)
                } else {
                    self.version = self.savedVersion
                    Logger.shared.logError("Saving note \(self.title) failed: \(error)", category: .document)
                }

                if self.pendingSave > 0 {
                    Logger.shared.logDebug("Trying again: Saving note \(self.title) as there were \(self.pendingSave) pending save operations", category: .document)
                    self.save(documentManager: documentManager, completion: completion)
                }
            }

            completion?(result)
        })
    }

    public static func instanciateNote(_ documentManager: DocumentManager,
                                       _ documentStruct: DocumentStruct,
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
        note.isPublic = documentStruct.isPublic
        if keepInMemory {
            try? GRDBDatabase.shared.append(note: note)
            appendToFetchedNotes(note)
        }
        return note
    }

    public static func fetch(_ documentManager: DocumentManager, title: String,
                             keepInMemory: Bool = true) -> BeamNote? {
        // Is the note in the cache?
        if let note = getFetchedNote(title) {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentByTitle(title: title) else {
            return nil
        }

//        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

        do {
            return try instanciateNote(documentManager, doc, keepInMemory: keepInMemory)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetch(_ documentManager: DocumentManager, id: UUID,
                             keepInMemory: Bool = true) -> BeamNote? {
        // Is the note in the cache?
        if let note = getFetchedNote(id) {
            return note
        }

        // Is the note in the document store?
        guard let doc = documentManager.loadDocumentById(id: id) else {
            return nil
        }

//        Logger.shared.logDebug("Note loaded:\n\(String(data: doc.data, encoding: .utf8)!)\n", category: .document)

        do {
            return try instanciateNote(documentManager, doc, keepInMemory: keepInMemory)
        } catch {
            Logger.shared.logError("Unable to decode note \(doc.title) (\(doc.id))", category: .document)
        }

        return nil
    }

    public static func fetchNotesWithType(_ documentManager: DocumentManager, type: DocumentType, _ limit: Int, _ fetchOffset: Int) -> [BeamNote] {
        return documentManager.loadDocumentsWithType(type: type, limit, fetchOffset).compactMap { doc -> BeamNote? in
            if let note = getFetchedNote(doc.title) {
                return note
            }
            do {
                return try instanciateNote(documentManager, doc)
            } catch {
                Logger.shared.logError("Unable to load document \(doc.title) (\(doc.id))", category: .document)
                return nil
            }
        }
    }

    // Beware that this function crashes whatever note with that title in the cache
    public static func create(_ documentManager: DocumentManager, title: String) -> BeamNote {
        assert(getFetchedNote(title) == nil)
        let note = BeamNote(title: title)
        appendToFetchedNotes(note)
        updateNoteCount()
        return note
    }

    public func observeDocumentChange() {
        observeDocumentChange(documentManager: AppDelegate.main.data.documentManager)
    }

    public func autoSave(_ relink: Bool) {
        if relink {
            try? GRDBDatabase.shared.append(note: self)
        }
        AppDelegate.main.data.noteAutoSaveService.addNoteToSave(self, relink)
    }

    public static func fetchOrCreate(_ documentManager: DocumentManager, title: String) -> BeamNote {
        // Is the note in the cache?
        if let note = fetch(documentManager, title: title) {
            return note
        }

        // create a new note and add it to the cache
        return create(documentManager, title: title)
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

    var isTodaysNote: Bool { (type == .journal) && (self === AppDelegate.main.data.todaysNote) }

    public static func indexAllNotes() {
        let documentManager = DocumentManager()
        try? GRDBDatabase.shared.clearElements()
        try? GRDBDatabase.shared.clearBidirectionalLinks()
        for title in documentManager.allDocumentsTitles() {
            if let note = BeamNote.fetch(documentManager, title: title) {
                try? GRDBDatabase.shared.append(note: note)
                for link in note.internalLinks {
                    GRDBDatabase.shared.appendLink(link)
                }
            }
        }
    }
}
