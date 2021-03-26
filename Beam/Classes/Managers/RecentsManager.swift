//
//  RecentsManager.swift
//  Beam
//
//  Created by Remi Santos on 26/03/2021.
//

import Foundation

class RecentsManager {

    private let maxNumberOfRecents = 5
    private let documentManager: DocumentManager
    private var recentsScores = [UUID: Int]()

    @Published private(set) var recentNotes = [BeamNote]()

    init(with documentManager: DocumentManager) {
        self.documentManager = documentManager
        self.fetchRecents()
    }

    private func fetchRecents() {
        recentNotes = documentManager.loadAllDocumentsWithLimit(maxNumberOfRecents, [NSSortDescriptor(key: "updated_at", ascending: false)]).map {
            BeamNote.fetchOrCreate(documentManager, title: $0.title)
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
        recentNotes.forEach { (note) in
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
}
