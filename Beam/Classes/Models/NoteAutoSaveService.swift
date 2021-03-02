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

    func addNoteToSave(_ note: BeamNote, _ detectLinks: Bool) {
        notesToSave[note] = (notesToSave[note] ?? false) || detectLinks
        noteToSaveChanged = true
    }

    @Published private var notesToSave: [BeamNote: Bool] = [:]
    @Published private var noteToSaveChanged: Bool = false
    init() {
        $noteToSaveChanged
            .dropFirst()
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
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
            note.key.save(documentManager: documentManager)
//            if note.value {
//                BeamNote.requestLinkDetection()
//            }
        }

        notesToSave = [:]
    }
}
