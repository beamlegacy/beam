//
//  RecentsManager.swift
//  Beam
//
//  Created by Remi Santos on 26/03/2021.
//

import Foundation
import Combine
import BeamCore

class RecentsManager: ObservableObject {

    private let maxNumberOfRecents = 5
    private let documentManager: DocumentManager
    private var recentsScores = [UUID: Int]()
    private var notesCancellables = Set<AnyCancellable>()
    private var documentManagerCancellables = Set<AnyCancellable>()

    @Published private(set) var recentNotes = [BeamNote]() {
        didSet { updateNotesObservers() }
    }

    init(with documentManager: DocumentManager) {
        self.documentManager = documentManager
        self.fetchRecents()
        self.observeDocumentManager()

        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { [weak self] _ in
                self?.fetchRecents()
            }
            .store(in: &notesCancellables)
    }

    private func shouldIncludeDocumentInRecents(_ doc: DocumentStruct) -> Bool {
        !doc.isEmpty || doc.documentType != .journal
    }

    private func fetchRecents() {
        var docs: [DocumentStruct] = []
        let scores = GRDBDatabase.shared.getTopNoteFrecencies(limit: maxNumberOfRecents * 2, paramKey: AutocompleteManager.noteFrecencyParamKey)
        let docsWithFrecencies = documentManager.loadDocumentsById(ids: Array(scores.keys)).filter(shouldIncludeDocumentInRecents).prefix(maxNumberOfRecents)
        docs.append(contentsOf: docsWithFrecencies)
        if docs.count < maxNumberOfRecents {
            // if we don't have much frecency scores let's use the recently updated notes.
            let docsRecentlyUpdated = documentManager.loadAllWithLimit(maxNumberOfRecents * 2, sortingKey: .updatedAt(false))
                .filter { !docs.contains($0) }
                .filter(shouldIncludeDocumentInRecents)
            docs.append(contentsOf: docsRecentlyUpdated.prefix(maxNumberOfRecents - docs.count))
        }
        recentNotes = docs.compactMap {
            // Maybe we could `instancateNote` automatically, to avoid refetching the CD object in `fetch`?
            // try? BeamNote.instanciateNote(documentManager, $0)
            BeamNote.fetch(id: $0.id, includeDeleted: false)
        }
    }

    private func updateVisibleRecents() {
        recentNotes = recentNotes.compactMap {
            BeamNote.fetch(id: $0.id, includeDeleted: false)
        }
    }

    func currentNoteChanged(_ note: BeamNote) {
        if !recentNotes.contains(where: { $0.id == note.id }) {
            var result = recentNotes.count >= maxNumberOfRecents ? removeLessUsedRecent() : recentNotes
            result.insert(note, at: 0)
            recentNotes = result
        }
        recentsScores[note.id] = (recentsScores[note.id] ?? 0) + 1
    }

    private func removeLessUsedRecent() -> [BeamNote] {
        var result = recentNotes
        var lowestScore = Int.max
        var lowestScoreId: UUID?
        recentNotes.forEach { note in
            let score = recentsScores[note.id] ?? 0
            if score <= lowestScore {
                lowestScore = score
                lowestScoreId = note.id
            }
        }
        if let noteId = lowestScoreId {
            recentsScores.removeValue(forKey: noteId)
            result.removeAll { $0.id == noteId }
        }
        return result
    }

    private func updateNotesObservers() {
        notesCancellables.removeAll()
        recentNotes.forEach { n in
            n.objectWillChange
                .receive(on: RunLoop.main)
                .sink { _ in self.objectWillChange.send() }
                .store(in: &notesCancellables)
        }
    }

    private func observeDocumentManager() {
        documentManagerCancellables.removeAll()
        DocumentManager.documentSaved.receive(on: DispatchQueue.main)
            .sink { [weak self] doc in
                guard self?.recentNotes.contains(where: { $0.id == doc.id }) == true else { return }
                self?.updateVisibleRecents()
            }.store(in: &documentManagerCancellables)

        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] docId in
                if let index = self?.recentNotes.firstIndex(where: { $0.id == docId }) {
                    self?.recentNotes.remove(at: index)
                }
            }.store(in: &documentManagerCancellables)

    }
}
