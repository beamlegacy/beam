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
        if let applicationSupportDirectory = paths.first {
            let indexPath = URL(fileURLWithPath: applicationSupportDirectory + "/index.sk")
            searchKit = SearchKit(indexPath)
        } else {
            searchKit = SearchKit(URL(fileURLWithPath: "~/Application Data/BeamApp/index.sk"))
        }

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
            print("Today's note loaded:\n\(note)\n")
            _todaysNote = note
        } else {
            let note = Note.createNote(CoreDataManager.shared.mainContext, todaysName)
            note.type = NoteType.journal.rawValue
            let bullet = note.createBullet(CoreDataManager.shared.mainContext, content: "")
            note.addToBullets(bullet)
            _todaysNote = note
            print("Today's note created:\n\(note)\n")

            CoreDataManager.shared.save()
        }

        updateJournal()
    }

    func updateJournal() {
        journal = Note.fetchAllWithType(CoreDataManager.shared.mainContext, .journal)
        print("Journal updated:\n\(journal)\n")
    }
}
