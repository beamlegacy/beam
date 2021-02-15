//
//  NoteAutoSaveService.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/02/2021.
//

import Foundation
import Combine

class NoteAutoSaveService: ObservableObject {
    private var scope = Set<AnyCancellable>()

    func addNoteToSave(_ note: BeamNote) {
        notesToSave.append(note)
        noteToSaveChanged = true
    }

    @Published private var notesToSave: [BeamNote] = []
    @Published private var noteToSaveChanged: Bool = false
    init() {
        $noteToSaveChanged
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [unowned self] _ in
            self.saveNotes()
        }.store(in: &scope)
    }

    deinit {
        // end and save
        saveNotes()
    }

    func saveNotes() {
        let documentManager = AppDelegate.main.data.documentManager

        for note in notesToSave {
            note.save(documentManager: documentManager)
        }

        notesToSave = []
    }
}
