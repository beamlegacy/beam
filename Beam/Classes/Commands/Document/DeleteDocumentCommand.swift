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

    private var allDocuments = false
    private var savedReferences: [UUID: Set<UUID>]?

    init(documentIds: [UUID] = [], allDocuments: Bool = false) {
        super.init(name: Self.name)
        self.allDocuments = allDocuments
        self.documentIds = documentIds
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

        if allDocuments {
            let ids = documents.map { $0.id }
            removeNotesFromIndex(ids)

            context?.softDelete(ids: ids) { _ in
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

            context?.softDelete(ids: documentIds) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError("Error while softDeleting \(self.documentIds): \(error)", category: .document)
                    completion?(false)
                case .success(let res):
                    if res {
                        removeNotesFromIndex(self.documentIds)
                        for note in notes {
                            note.recursiveChangePropagationEnabled = true
                        }
                    }
                    completion?(res)
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
        let promises: [Promises.Promise<Bool>] = documents.compactMap { context?.save($0) }
        Promises.all(promises).then { [weak self] dones in
            self?.restoreNoteReferences()
            let done = dones.reduce(into: false) { $0 = $0 || $1 }
            completion?(done)
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
