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
    private var recentsScores = [UUID: Int]()
    private var notesCancellables = Set<AnyCancellable>()
    private var collectionCancellables = Set<AnyCancellable>()

    @Published private(set) var recentNotes = [BeamNote]() {
        didSet { updateNotesObservers() }
    }

    init() {
        try? self.fetchRecents()
        self.setupObserver()

        BeamData.shared.$currentDatabase
            .sink { [weak self] _ in
                try? self?.fetchRecents()
            }
            .store(in: &notesCancellables)
    }

    private func shouldIncludeDocumentInRecents(_ doc: BeamDocument) -> Bool {
        !doc.isEmpty || doc.documentType != .journal
    }

    private func fetchRecents() throws {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }
        var docs: [BeamDocument] = []
        let scores = BeamData.shared.noteLinksAndRefsManager?.getTopNoteFrecencies(limit: maxNumberOfRecents * 2, paramKey: AutocompleteManager.noteFrecencyParamKey) ?? [:]
        let docsWithFrecencies = try collection.fetch(filters: [.ids(Array(scores.keys))]) .filter(shouldIncludeDocumentInRecents).prefix(maxNumberOfRecents)
        docs.append(contentsOf: docsWithFrecencies)
        if docs.count < maxNumberOfRecents {
            // if we don't have much frecency scores let's use the recently updated notes.
            let docsRecentlyUpdated = try collection.fetch(filters: [.limit(maxNumberOfRecents * 2, offset: 0)], sortingKey: .updatedAt(false))
                .filter { !docs.contains($0) }
                .filter(shouldIncludeDocumentInRecents)
            docs.append(contentsOf: docsRecentlyUpdated.prefix(maxNumberOfRecents - docs.count))
        }
        recentNotes = docs.compactMap {
            // Maybe we could `instancateNote` automatically, to avoid refetching the CD object in `fetch`?
            // try? BeamNote.instanciateNote(documentManager, $0)
            BeamNote.fetch(id: $0.id)
        }
    }

    private func updateVisibleRecents() {
        recentNotes = recentNotes.compactMap {
            BeamNote.fetch(id: $0.id)
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

    private func setupObserver() {
        collectionCancellables.removeAll()
        BeamDocumentCollection.documentSaved.receive(on: DispatchQueue.main)
            .sink { [weak self] doc in
                guard self?.recentNotes.contains(where: { $0.id == doc.id }) == true else { return }
                self?.updateVisibleRecents()
            }.store(in: &collectionCancellables)

        BeamDocumentCollection.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] deleted in
                if let index = self?.recentNotes.firstIndex(where: { $0.id == deleted.id }) {
                    self?.recentNotes.remove(at: index)
                }
            }.store(in: &collectionCancellables)

    }
}
