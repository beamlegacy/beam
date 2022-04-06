//
//  DeleteDocumentCommand.swift
//  Beam
//
//  Created by Remi Santos on 25/05/2021.
//

import Foundation
import BeamCore
import Promises

class DeleteDocument: DocumentCommand {
    static let name: String = "DeleteDocument"

    private let shouldClearData = true
    private var allDocuments = false
    private var savedReferences: [UUID: Set<UUID>]?

    init(documentIds: [UUID] = [], allDocuments: Bool = false) {
        super.init(name: Self.name)
        self.allDocuments = allDocuments
        let todayId = AppDelegate.main.data.todaysNote.id
        self.documentIds = documentIds.filter { $0 != todayId }
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    // swiftlint:disable function_body_length
    override func run(context: DocumentManager?, completion: ((Bool) -> Void)?) {
        let signpost = SignPost("DeleteDocumentCommand")
        signpost.begin("run")
        defer {
            signpost.end("run")
        }
        var notesToUpdate = Set<UUID>()

        documents = allDocuments ? (context?.loadAll() ?? []) : documentIds.compactMap { context?.loadById(id: $0, includeDeleted: false) }
        BeamNote.purgingNotes = BeamNote.purgingNotes.union(Set(documents.map { $0.id }))

        let removeNotesFromIndex: ([UUID]) -> Void = { ids in
            do {
                try GRDBDatabase.shared.removeNotes(ids)
            } catch {
                Logger.shared.logError("Impossible to remove all notes from indexing: \(error)", category: .search)
            }
        }

        DocumentManager.disableNotifications()
        defer { DocumentManager.enableNotifications() }

        let todayId = AppDelegate.main.data.todaysNote.id

        if allDocuments {
            let ids: [UUID] = documents.compactMap { note in
                guard todayId != note.id else { return nil }
                return note.id
            }
            removeNotesFromIndex(ids)

            context?.softDelete(ids: ids, clearData: shouldClearData) { _ in
                completion?(true)
            }
        } else {
            saveDocumentsLinks().forEach { notesToUpdate.insert($0.noteID) }
            unpublishNotes(in: documents)

            var notes = Set<BeamNote>()
            for id in documentIds {
                guard let note = BeamNote.getFetchedNote(id) else { continue }
                note.recursiveChangePropagationEnabled = false
                note.deleted = true
                notes.insert(note)
            }

            context?.softDelete(ids: documentIds, clearData: shouldClearData) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError("Error while softDeleting \(self.documentIds): \(error)", category: .document)
                    completion?(false)
                case .success:
                    removeNotesFromIndex(self.documentIds)
                    for note in notes {
                        note.recursiveChangePropagationEnabled = true
                    }
                    completion?(true)
                }
            }
        }

        DispatchQueue.main.async {
            signpost.begin("update note names")
            notesToUpdate.forEach { id in
                guard let note = BeamNote.fetch(id: id, includeDeleted: false, keepInMemory: false) else { return }
                note.recursiveChangePropagationEnabled = false
                note.updateNoteNamesInInternalLinks(recursive: true)
                _ = note.syncedSave()
                note.recursiveChangePropagationEnabled = true
            }
            signpost.end("update note names")
        }
    }

    override func undo(context: DocumentManager?, completion: ((Bool) -> Void)?) {
        guard !documents.isEmpty else {
            completion?(false)
            return
        }
        var ids: [UUID] = []
        var restoreData: [UUID: Data] = [:]
        documents.forEach {
            ids.append($0.id)
            if shouldClearData {
                restoreData[$0.id] = $0.data
            }
        }
        context?.softUndelete(ids: ids, restoreData: restoreData) { [weak self] result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error while softUndeleting \(ids): \(error)", category: .document)
                completion?(false)
            case .success:
                for id in ids {
                    guard let note = BeamNote.getFetchedNote(id) else { continue }
                    note.recursiveChangePropagationEnabled = true
                    note.deleted = false
                }
                self?.restoreNoteReferences()
                completion?(true)
            }
        }
    }

    private func unpublishNotes(in docs: [DocumentStruct]) {
        let toUnpublish = docs.filter({ $0.isPublic })
        toUnpublish.forEach { doc in
            BeamNoteSharingUtils.unpublishNote(with: doc.id, completion: { _ in })
        }
    }

    private func saveDocumentsLinks() -> [BeamNoteReference] {
        var noteLinks = [BeamNoteReference]()
        var refsMapping = [UUID: Set<UUID>]()
        documents.forEach { doc in
            let links = (try? GRDBDatabase.shared.fetchLinks(toNote: doc.id).map({ bidiLink in
                BeamNoteReference(noteID: bidiLink.sourceNoteId, elementID: bidiLink.sourceElementId)
            })) ?? []

            if !links.isEmpty {
                noteLinks.append(contentsOf: links)
                refsMapping[doc.id] = Set(links.map { $0.noteID })
            }
        }
        savedReferences = refsMapping
        return noteLinks
    }

    private func restoreNoteReferences() {
        documents.forEach { doc in
            guard let storedRefs = savedReferences?[doc.id], !storedRefs.isEmpty, let note = BeamNote.fetch(id: doc.id, includeDeleted: true)
            else { return }
            note.references.forEach { ref in
                ref.element?.text.makeLinksToNoteExplicit(forNote: note.title)
            }
        }
    }
}

extension CommandManagerAsync where Context == DocumentManager {
    func deleteDocuments(ids: [UUID], in context: DocumentManager, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(documentIds: ids)
        run(command: cmd, on: context, completion: completion)
    }

    func deleteAllDocuments(in context: DocumentManager, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(allDocuments: true)
        run(command: cmd, on: context, completion: completion)
    }
}
