//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation

class BeamData: ObservableObject {
    var _todaysNote: Note?
    var todaysNote: Note {
        if let note = _todaysNote, note.title == todaysName {
            return note
        }

        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [Note] = []

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
            _todaysNote = note
        } else {
            let note = Note.createNote(CoreDataManager.shared.mainContext, todaysName)
            note.type = NoteType.journal.rawValue
            let bullet = note.createBullet(CoreDataManager.shared.mainContext, content: "")
            note.addToBullets(bullet)
            _todaysNote = note
//            print("Today's note created:\n\(note)\n")

            CoreDataManager.shared.save()
        }

        updateJournal()
    }

    func updateJournal() {
        let _journal = Note.fetchAllWithType(CoreDataManager.shared.mainContext, .journal)
        var newJournal = [Note]()

        // purge journal from empty notes:
        for j in _journal {
            if j.title != todaysName, j.bullets?.count == 1, let bullet = j.bullets?.first, bullet.content.isEmpty {
                j.delete()
            } else {
                newJournal.append(j)
            }
        }

        journal = newJournal
//        print("Journal updated:\n\(journal)\n")
    }
}
