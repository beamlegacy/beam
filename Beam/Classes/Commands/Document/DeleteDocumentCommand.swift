//
//  DeleteDocumentCommand.swift
//  Beam
//
//  Created by Remi Santos on 25/05/2021.
//

import Foundation
import BeamCore

class DeleteDocument: DocumentCommand, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    static let name: String = "DeleteDocument"

    private let shouldClearData = true
    private var allDocuments = false
    private var savedReferences: [UUID: Set<UUID>]?

    init(documentIds: [UUID] = [], allDocuments: Bool = false) {
        super.init(name: Self.name)
        self.allDocuments = allDocuments
        let todayId = BeamData.shared.todaysNote.id
        self.documentIds = documentIds.filter { $0 != todayId }
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func run(context: BeamDocumentCollection?, completion: ((Bool) -> Void)?) {
        let signpost = SignPost("DeleteDocumentCommand")
        signpost.begin("run")
        defer {
            signpost.end("run")
        }
        var notesToUpdate = Set<UUID>()

        documents = allDocuments ? ((try? context?.fetch(filters: [])) ?? []) : documentIds.compactMap { try? context?.fetchFirst(filters: [.id($0)]) }
        BeamNote.purgingNotes = BeamNote.purgingNotes.union(Set(documents.map { $0.id }))

        let removeNotesFromIndex: ([UUID]) -> Void = { ids in
            do {
                try BeamData.shared.noteLinksAndRefsManager?.removeNotes(ids)
            } catch {
                Logger.shared.logError("Impossible to remove all notes from indexing: \(error)", category: .search)
            }
        }

        BeamDocumentCollection.disableNotifications()
        defer { BeamDocumentCollection.enableNotifications() }

        let todayId = BeamData.shared.todaysNote.id

        if allDocuments {
            let ids: [UUID] = documents.compactMap { note in
                guard todayId != note.id else { return nil }
                return note.id
            }
            removeNotesFromIndex(ids)

            do {
                try context?.delete(self, filters: [.ids(ids)])
                completion?(true)
            } catch {
                Logger.shared.logError("Error while softDeleting \(ids): \(error)", category: .document)
                completion?(false)
            }
        } else {
            saveDocumentsLinks().forEach { notesToUpdate.insert($0.noteID) }
            unpublishNotes(in: documents)

            var notes = Set<BeamNote>()
            for id in documentIds {
                guard let note = BeamNote.getFetchedNote(id) else { continue }
                note.recursiveChangePropagationEnabled = false
                notes.insert(note)
            }

            do {
                try context?.delete(self, filters: [.ids(documentIds)])
                completion?(true)
            } catch {
                Logger.shared.logError("Error while softDeleting \(self.documentIds): \(error)", category: .document)
                completion?(false)
            }
        }

        DispatchQueue.main.async {
            signpost.begin("update note names")
            notesToUpdate.forEach { id in
                guard let note = BeamNote.fetch(id: id, keepInMemory: false) else { return }
                note.recursiveChangePropagationEnabled = false
                note.updateNoteNamesInInternalLinks(recursive: true)
                _ = note.save(self)
                note.recursiveChangePropagationEnabled = true
            }
            signpost.end("update note names")
        }
    }

    override func undo(context: BeamDocumentCollection?, completion: ((Bool) -> Void)?) {
        guard let context = context else {
            completion?(false)
            return
        }

        guard !documents.isEmpty else {
            completion?(false)
            return
        }

        for document in documents {
            _ = try? context.save(self, document, indexDocument: true)
        }
        completion?(true)
    }

    private func unpublishNotes(in docs: [BeamDocument]) {
        let toUnpublish = docs.filter({ $0.isPublic })
        toUnpublish.forEach { doc in
            if let note = BeamNote.getFetchedNote(doc.id) {
                if note.publicationStatus.isOnPublicProfile {
                    BeamNoteSharingUtils.removeFromProfile(note) { result in
                        switch result {
                        case .success:
                            BeamNoteSharingUtils.unpublishNote(with: doc.id, completion: { _ in })
                        case .failure:
                            break
                        }
                    }
                } else {
                    BeamNoteSharingUtils.unpublishNote(with: doc.id, completion: { _ in })
                }
            }
        }
    }

    private func saveDocumentsLinks() -> [BeamNoteReference] {
        var noteLinks = [BeamNoteReference]()
        var refsMapping = [UUID: Set<UUID>]()
        documents.forEach { doc in
            let links = (try? BeamData.shared.noteLinksAndRefsManager?.fetchLinks(toNote: doc.id).map({ bidiLink in
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
            guard let storedRefs = savedReferences?[doc.id], !storedRefs.isEmpty, let note = BeamNote.fetch(id: doc.id)
            else { return }
            note.references.forEach { ref in
                ref.element?.text.makeLinksToNoteExplicit(self, forNote: note.title)
            }
        }
    }
}

extension CommandManagerAsync where Context == BeamDocumentCollection {
    func deleteDocuments(ids: [UUID], in context: BeamDocumentCollection, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(documentIds: ids)
        run(command: cmd, on: context, completion: completion)
    }

    func deleteAllDocuments(in context: BeamDocumentCollection, completion: ((Bool) -> Void)? = nil) {
        let cmd = DeleteDocument(allDocuments: true)
        run(command: cmd, on: context, completion: completion)
    }
}
