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

    override func run(context: DocumentManager?, completion: ((Bool) -> Void)?) {
        var noteLinks: [BeamNoteReference]?

        let callback = {
            DispatchQueue.main.async {
                noteLinks?.forEach { ref in
                    ref.note?.updateNoteNamesInInternalLinks(recursive: true)
                }
            }
        }

        if allDocuments {
            documents = context?.loadAll() ?? []

            context?.softDelete(ids: documents.map { $0.id }) { _ in
                callback()
                completion?(true)
            }
        } else {
            documents = documentIds.compactMap { context?.loadById(id: $0) }
            noteLinks = saveDocumentsLinks()
            unpublishNotes(in: documents)

            context?.softDelete(ids: documentIds) { _ in
                callback()
                completion?(true)
            }
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
            if let note = BeamNote.fetch(id: doc.id) {
                let links = note.links
                if !links.isEmpty {
                    noteLinks.append(contentsOf: links)
                    refsMapping[doc.id] = Set(links.map { $0.noteID })
                    BeamData.updateTitleIdNoteMapping(noteId: note.id, currentName: note.title, newName: nil)
                }
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
