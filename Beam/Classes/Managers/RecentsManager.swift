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
    private var deletionsCancellables = Set<AnyCancellable>()

    @Published private(set) var recentNotes = [BeamNote]() {
        didSet { updateNotesObservers() }
    }

    init(with documentManager: DocumentManager) {
        self.documentManager = documentManager
        self.fetchRecents()
        self.observeCoreDataChanges()

        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { [weak self] _ in
                self?.fetchRecents()
            }
            .store(in: &notesCancellables)
    }

    private func fetchRecents() {
        recentNotes = documentManager.loadAllWithLimit(maxNumberOfRecents, sortingKey: .updatedAt(false)).compactMap {
            // Maybe we could `instancateNote` automatically, to avoid refetching the CD object in `fetch`?
            // try? BeamNote.instanciateNote(documentManager, $0)
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

    private func observeCoreDataChanges() {
        DocumentManager.documentSaved.receive(on: DispatchQueue.main)
            .sink { [weak self] documentStruct in
                guard let self = self else { return }
                if documentStruct.deletedAt != nil {
                    self.fetchRecents()
                }
            }.store(in: &deletionsCancellables)

        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                   guard let self = self else { return }
                self.fetchRecents()
            }.store(in: &deletionsCancellables)

    }
}
