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
    var scores = Scores()

    @Published var showTabStats = false

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager

    init() {
        documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

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
        _todaysNote = BeamNote.fetchOrCreate(documentManager, title: todaysName)
        _todaysNote?.type = .journal

        updateJournal()
    }

    func updateJournal() {
        var _journal = BeamNote.fetchNotesWithType(documentManager, type: .journal)
        _journal.insert(todaysNote, at: 0)
        journal = _journal
    }
}
