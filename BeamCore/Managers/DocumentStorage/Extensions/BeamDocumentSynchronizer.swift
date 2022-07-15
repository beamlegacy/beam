//
//  BeamDocumentSynchronizer.swift
//  Beam
//
//  Created by Sebastien Metrot on 30/05/2022.
//

import Foundation
import BeamCore
import Combine
import Accelerate

class BeamDocumentSynchronizer: BeamObjectManagerDelegate, BeamDocumentSource {
    static var beamObjectType = BeamObjectObjectType.document
    static var sourceId: String { "\(Self.self)" }

    weak public private(set) var account: BeamAccount?

    public private(set) static var conflictPolicy = BeamObjectConflictResolution.fetchRemoteAndError
    public private(set) static var backgroundQueue = DispatchQueue.global(qos: .default)
    private var documentsQueue: DispatchQueue = DispatchQueue(label: "BeamDocumentSynchronizer documentsQueue", qos: .userInitiated)

    private var scope = Set<AnyCancellable>()

    private let throttleDelay: Int = Configuration.env != .test ? 1 : 0

    private var documentsCancellables: [UUID: AnyCancellable] = [:]
    private var subjects: [UUID: PassthroughSubject<BeamDocument, Never>] = [:]

    init(account: BeamAccount) {
        self.account = account

        setupObservers()
    }

    private func setupObservers() {
        BeamDocumentCollection.documentSaved
            .filter({ [weak self] document in
                document.database?.account == self?.account
            })
            .sink { [weak self] document in
                self?.sendSavedDocument(document)
            }.store(in: &scope)

        BeamDocumentCollection.documentDeleted
            .filter({ [weak self] deletedDocument in
                deletedDocument.database?.account == self?.account
            })
            .sink { [weak self] deletedDocument in
                self?.sendDeletedDocument(deletedDocument)
            }.store(in: &scope)
    }

    // swiftlint:disable function_body_length
    private func sendSavedDocument(_ document: BeamDocument) {
        Logger.shared.logInfo("BeamDocumentSynchronizer.sendSavedDocument called with \(document.id)", category: .sync)
        if documentsCancellables[document.id] != nil {
            let subject = subjects[document.id]
            subject?.send(document)
            Logger.shared.logInfo("Reused publisher for \(document.id)", category: .sync)
        } else {
            let subject = PassthroughSubject<BeamDocument, Never>()
            let publisher = subject.eraseToAnyPublisher()
            let cancellable = publisher.debounce(for: .seconds(throttleDelay), scheduler: DispatchQueue.main)
                .sink { [weak self] document in
                    defer {
                        self?.documentsCancellables.removeValue(forKey: document.id)
                        self?.subjects.removeValue(forKey: document.id)
                    }

                    self?.documentsQueue.async {
                        do {
                            var updatedDocument: BeamDocument!
                            if document.deletedAt != nil {
                                updatedDocument = document
                            } else {
                                guard let reloadedDocument = try document.collection?.fetchWithId(document.id) else {
                                    Logger.shared.logError("Failed to reload document \(document)", category: .sync)
                                    return
                                }
                                updatedDocument = reloadedDocument
                            }
                            try self?.saveOnBeamObjectAPI(updatedDocument) { result in
                                switch result {
                                case .success:
                                    Logger.shared.logInfo("\(document.id) saved on server", category: .sync)
                                case .failure(let error):
                                    Logger.shared.logError("Failed to save on server \(document): \(error)", category: .sync)
                                }
                            }
                        } catch {
                            Logger.shared.logError("Failed to save on server \(document): \(error)", category: .sync)
                        }
                    }
                }
            documentsCancellables[document.id] = cancellable
            subjects[document.id] = subject
            subject.send(document)
        }
    }

    private func sendDeletedDocument(_ deletedDocument: BeamDocument) {
        Logger.shared.logInfo("BeamDocumentSynchronizer.sendDeletedDocument called with \(deletedDocument.id)", category: .sync)
        guard deletedDocument.hasBeenSyncedOnce else {
            Logger.shared.logInfo("\(deletedDocument.id) was never sync, nothing is sent on server", category: .sync)
            return
        }

        sendSavedDocument(deletedDocument)
    }

    func forceReceiveAll() throws {
        let currentDB = BeamData.shared.currentDatabase
        try receivedObjects(try BeamObjectChecksum.previousSavedObjects(type: BeamDocument.self).compactMap({
            var document = $0
            document.database = currentDB
            return document
        }))
    }

    func receivedObjects(_ objects: [BeamDocument]) throws {
        try receivedObjects(objects, destination: nil)
    }

    /// This version of receivedObjects can force the use of a destination database, that is all the incomming BeamDocuments will be deleted from their original database if it isn't the given destination.
    //swiftlint:disable:next cyclomatic_complexity
    func receivedObjects(_ objects: [BeamDocument], destination: BeamDatabase?) throws {
        Logger.shared.logInfo("BeamDocumentSynchronizer.receivedObjects called with \(objects.map { $0.id })", category: .sync)

        guard let account = account else {
            Logger.shared.logInfo("No account, cancelling", category: .sync)
            return
        }
        // Then look for the database and update it, or create it if not found
        let currentDB = BeamData.shared.currentDatabase
        for var document in objects {
            guard let dbId = destination?.id ?? document.databaseId,
                  let database = destination ?? (try? account.loadDatabase(dbId)),
                  let collection = database.collection
            else {
                Logger.shared.logError("Trying to sync a document in a database that doesn't exist \(document)", category: .sync)
                continue
            }

            Logger.shared.logInfo("\(document.id): database will be changed from \(String(describing: document.database?.id)) to \(database)", category: .sync)
            document.database = database

            let isInCurrentDB = database == currentDB
            do {
                if document.deletedAt != nil {
                    try receiveDeletedDocument(document)
                } else if let date = BeamNoteType.dateFrom(journalDateInt: document.journalDate) {
                    if isInCurrentDB, let note = BeamNote.getFetchedNote(date) {
                        receiveConflictingLoadedJournal(document, note: note)
                    } else {
                        try receiveConflictingJournal(document, withDate: document.journalDate, destination: destination)
                    }
                } else if isInCurrentDB, let note = BeamNote.getFetchedNote(document.title), note.id != document.id {
                    try receiveConflictingTitleLoadedDocument(document, note: note)
                } else if let localDocument = try? collection.fetchFirst(filters: [.title(document.title)]), localDocument.id != document.id {
                        try receiveConflictingTitleDocument(document, localDocument: localDocument)
                } else if isInCurrentDB, let note = BeamNote.getFetchedNote(document.id) {
                    receiveConflictingLoadedDocument(document, note: note)
                } else if let localDocument = try? collection.fetchFirst(filters: [.id(document.id)]) {
                    let localStruct = BeamDocument(document: localDocument)
                    try receiveDocument(document, localDocument: localStruct)
                } else {
                    try receiveDocument(document)
                }
            } catch {
                Logger.shared.logError("Error receiving document from sync: \(document): \(error)", category: .document)
                Logger.shared.logError("document \(document.titleAndId) skipped", category: .document)
            }
        }
    }

    func allObjects(updatedSince: Date?) throws -> [BeamDocument] {
        var documents: [BeamDocument] = []
        guard let databases = account?.allDatabases else { return documents }

        var filters: [DocumentFilter] = []
        if let updatedSince = updatedSince {
            filters.append(.updatedSince(updatedSince))
        }

        for database in databases {
            try database.load()
            guard let collection = database.collection else { continue }
            let fetchedDocuments = try collection.fetch(filters: filters)
            documents.append(contentsOf: fetchedDocuments)
        }

        return documents
    }

    func willSaveAllOnBeamObjectApi() {
    }

    func manageConflict(_ object: BeamDocument, _ remoteObject: BeamDocument) throws -> BeamDocument {
        guard let account = account,
              let dbId = remoteObject.databaseId,
              let database = (try? account.loadDatabase(dbId)),
              let collection = database.collection
        else {
            Logger.shared.logError("Trying to sync a document in a database that doesn't exist \(remoteObject)", category: .sync)
            return remoteObject
        }

        try receivedObjects([remoteObject])

        if let updatedObject = try collection.fetchWithId(remoteObject.id) {
            Logger.shared.logError("Document \(remoteObject) was changed to \(updatedObject) during conflict resolution", category: .sync)
            return updatedObject
        }

        Logger.shared.logError("Document \(remoteObject) was deleted during conflict resolution", category: .sync)
        var deletedObject = remoteObject
        deletedObject.deletedAt = BeamDate.now
        return deletedObject
    }

    func saveObjectsAfterConflict(_ objects: [BeamDocument]) throws {
        // We have already saved everything that needs to be saved during manageConflict
    }
}

// MARK: Object reception:
extension BeamDocumentSynchronizer {
    private func receiveDeletedDocument(_ document: BeamDocument) throws {
        Logger.shared.logInfo("\(document.id) is deleted", category: .sync)
        // We can directly delete from the db
        _ = try document.collection?.delete(self, filters: [.id(document.id)])
    }

    private func receiveConflictingLoadedDocument(_ document: BeamDocument, note: BeamNote) {
        Logger.shared.logInfo("receiveConflictingLoadedDocument \(document.titleAndId) (note: \(note.titleAndId))", category: .sync)
        // We have a local note loaded with the same id, let's update it inline:
        guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: false) else { return }
        if document.title != note.title {
            remoteNote.title = document.title
            DispatchQueue.mainSync {
                note.updateTitle(self, remoteNote.title)
            }
        }
        let ancestorStruct = document.previousSavedObject ?? document
        guard let ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false) else { return }

        DispatchQueue.mainSync {
            // We have to block the main thread to merge the document
            // other wise the editor may have a race condition
            note.merge(other: remoteNote, ancestor: ancestorNote, advantageOther: false)
            _ = note.save(self)
        }
    }

    private func receiveConflictingLoadedJournal(_ document: BeamDocument, note: BeamNote) {
        Logger.shared.logInfo("receiveConflictingLoadedJournal \(document.titleAndId) (note: \(note.titleAndId))", category: .sync)
        // there a conflicting journal note (with the same day)
        DispatchQueue.mainSync {
            // We have to block the main thread to merge the document
            // other wise the editor may have a race condition

            // Do we have a different id?
            if document.id == note.id {
                guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: false) else { return }
                // then we merge the changes in the local note
                let ancestorStruct = document.previousSavedObject ?? document
                let ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false)
                note.merge(other: remoteNote, ancestor: ancestorNote ?? note, advantageOther: false)
                _ = note.save(self)
            } else {
                self.mergeToBestNote(note: note, document: document)
            }
        }
    }

    /// This method takes note, a BeamNote currently being edited, and an incoming Document and tries to make the best out of them by merging them and keeping the one that best fits the sync needs: we try to keep the document that conserve what's already in the sync.
    private func mergeToBestNote(note: BeamNote, document: BeamDocument) {
        guard let remoteNote = try? BeamNote.instanciateNote(document, keepInMemory: false) else {
            Logger.shared.logError("Couldn't instanciate remote note from document \(document)", category: .document)
            return
        }

        guard let localDocument = note.document else {
            Logger.shared.logError("Couldn't get BeamDocument from note \(note)", category: .document)
            return
        }

        let ancestorNote: BeamNote?
        let noteToKeep: BeamNote
        let noteToDelete: BeamNote

        if note.document?.hasBeenSyncedOnce == true {
            let ancestorStruct = localDocument.previousSavedObject ?? localDocument
            ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false)
            noteToKeep = note
            noteToDelete = remoteNote
            Logger.shared.logInfo("-> Choose to keep localNote", category: .sync)
        } else {
            let ancestorStruct = document.previousSavedObject ?? document
            ancestorNote = try? BeamNote.instanciateNote(ancestorStruct, keepInMemory: false)
            noteToKeep = remoteNote
            noteToDelete = note
            Logger.shared.logInfo("-> Choose to keep remoteNote", category: .sync)
        }

        noteToKeep.merge(other: noteToDelete, ancestor: ancestorNote ?? noteToKeep, advantageOther: false)
        try? noteToDelete.database?.collection?.delete(self, filters: [.id(noteToDelete.id)])
        DispatchQueue.mainSync {
            _ = noteToKeep.save(self)
        }
    }

    private func receiveConflictingJournal(_ document: BeamDocument, withDate journalDate: Int64, destination: BeamDatabase?) throws {
        Logger.shared.logInfo("receiveConflictingJournal \(document.titleAndId) (journal date: \(journalDate))", category: .sync)
        guard let localDocument = try (destination?.collection ?? document.collection)?.fetchFirst(filters: [.journalDate(journalDate)])
        else {
            // There is no local journal document for said date, we can treat it as a normal doc:
            try receiveDocument(document)
            return
        }

        guard let localNote = try? BeamNote.instanciateNote(localDocument, keepInMemory: false) else {
            // The local document is unreadable, might have been deleted? Let's store this one then
            Logger.shared.logError("Unable to instantiate local journal note \(localDocument.titleAndId)", category: .document)
            try receiveDocument(document)
            return
        }

        mergeToBestNote(note: localNote, document: document)
    }

    func newTitleForConflict(_ note: BeamNote) -> String? {
        guard let collection = note.database?.collection else { return nil }
        let MAX_AUTO_INCREMENT = 100
        let title = note.title
        var (originalTitle, index) = title.originalTitleWithIndex()
        var newTitle = title
        repeat {
            newTitle = "\(originalTitle) (\(index))"
            index += 1
        } while index < MAX_AUTO_INCREMENT && (try? collection.fetchFirst(filters: [.title(newTitle)])) != nil
        guard index < MAX_AUTO_INCREMENT else { return nil }
        return newTitle
    }

    func receiveConflictingTitleLoadedDocument(_ document: BeamDocument, note: BeamNote) throws {
        Logger.shared.logInfo("receiveConflictingTitleLoadedDocument \(document.titleAndId) (note: \(note.titleAndId))", category: .sync)
        let newTitle = newTitleForConflict(note) ?? note.titleAndId
        DispatchQueue.mainSync {
            note.updateTitle(self, newTitle)
        }
        var doc = document
        if doc.version > 0 {
            // Start at zero if this note it new
            doc.version += 1
        }
        _ = try doc.collection?.save(self, doc, indexDocument: true)
    }

    func receiveConflictingTitleDocument(_ document: BeamDocument, localDocument: BeamDocument) throws {
        Logger.shared.logInfo("receiveConflictingTitleDocument \(document.titleAndId) (local: \(localDocument.titleAndId))", category: .sync)
        guard let localNote = try? BeamNote.instanciateNote(localDocument, keepInMemory: false),
              let collection = localNote.database?.collection
        else {
            Logger.shared.logError("Unable to load existing note to rename \(localDocument.titleAndId)", category: .document)
            return
        }

        guard !localNote.isEntireNoteEmpty() else {
            try? collection.delete(self, filters: [.id(localNote.id)])

            let localDocument = try? collection.fetchFirst(filters: [.id(document.id)])
            try receiveDocument(document, localDocument: localDocument)
            return
        }
        try receiveConflictingTitleLoadedDocument(document, note: localNote)
    }

    private func receiveDocument(_ document: BeamDocument, localDocument: BeamDocument? = nil) throws {
        Logger.shared.logInfo("receiveDocument \(document.titleAndId) (local: \(localDocument?.titleAndId ?? "nil"))", category: .sync)
        var doc = document
        if let localDocument = localDocument {
            doc.version = localDocument.version + 1

            if document.title != localDocument.title {
                DispatchQueue.mainSync {
                    BeamNote.updateTitleLocally(self, id: document.id, document.title)
                }
            }
        }

        let indexDocument = BeamObjectManager.fullSyncRunning.load(ordering: .relaxed) == false
        _ = try doc.collection?.save(self, doc, indexDocument: indexDocument)
    }
}
