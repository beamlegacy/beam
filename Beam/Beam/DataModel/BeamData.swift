//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation

class BeamData: ObservableObject {
    var _todaysNote: BeamNote?
    var todaysNote: BeamNote {
        if let note = _todaysNote, note.title == todaysName {
            return note
        }

        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [BeamNote] = []

    var searchKit: SearchKit

    var cookies: HTTPCookieStorage

    init() {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let directory = paths.first ?? "~/Application Data/BeamApp/"
        let indexPath = URL(fileURLWithPath: directory + "/index.sk")
        searchKit = SearchKit(indexPath)

        cookies = HTTPCookieStorage()
    }

    var todaysName: String {
        let fmt = DateFormatter()
        let today = Date()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: today)
    }

    func setupJournal() {
        if let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, todaysName) {
//            print("Today's note loaded:\n\(note)\n")
            _todaysNote = beamNoteFrom(note: note)
        } else {
            let note = Note.createNote(CoreDataManager.shared.mainContext, todaysName)
            note.type = NoteType.journal.rawValue
            let bullet = note.createBullet(CoreDataManager.shared.mainContext, content: "")
            note.addToBullets(bullet)
            _todaysNote = beamNoteFrom(note: note)
//            print("Today's note created:\n\(note)\n")

            try? CoreDataManager.shared.save()
        }

        updateJournal()
    }

    func updateJournal() {
        let _journal = Note.fetchAllWithType(CoreDataManager.shared.mainContext, .journal)
        var newJournal = [BeamNote]()

        // purge journal from empty notes:
        for note in _journal {
            if note.title != todaysName, note.bullets?.count == 1, let bullet = note.bullets?.first, bullet.content.isEmpty {
                note.delete()
            } else {
                newJournal.append(beamNoteFrom(note: note))
            }
        }

        journal = newJournal
//        print("Journal updated:\n\(journal)\n")
    }
}
