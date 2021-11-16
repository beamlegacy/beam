//
//  NoteAutoSaveService.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/02/2021.
//

import Foundation
import Combine
import BeamCore

class NoteAutoSaveService: ObservableObject {
    private var scope = Set<AnyCancellable>()

    func addNoteToSave(_ note: BeamNote) {
        notesToSave[note] = (notesToSave[note] ?? false)
        noteToSaveChanged = true
    }

    @Published private var notesToSave: [BeamNote: Bool] = [:]
    @Published private var noteToSaveChanged: Bool = false
    init() {
        $noteToSaveChanged
            .dropFirst()
            .sink { [unowned self] _ in
            self.saveNotes()
        }.store(in: &scope)
    }

    deinit {
        // end and save
        saveNotes()
    }

    func saveNotes() {
        for note in notesToSave {
            note.key.save()
//            if note.value {
//                BeamNote.requestLinkDetection()
//            }
        }

        notesToSave = [:]
    }
}
