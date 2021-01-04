//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation

public class BeamData: ObservableObject {
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
    var index: Index
    var scores = Scores()
    @Published var noteCount = 0

    @Published var showTabStats = false

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager

    static var dataFolder: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return paths.first ?? "~/Application Data/BeamApp/"
    }

    static var searchKitPath: URL { return URL(fileURLWithPath: dataFolder + "/index.sk") }
    static var indexPath: URL { return URL(fileURLWithPath: dataFolder + "/index.beamindex") }

    init() {
        documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

        searchKit = SearchKit(Self.searchKitPath)
        index = Index.loadOrCreate(Self.indexPath)

        cookies = HTTPCookieStorage()

        updateNoteCount()
    }

    deinit {
        // save search index
        try? index.saveTo(Self.indexPath)
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

    func updateNoteCount() {
        noteCount = Document.countWithPredicate(CoreDataManager.shared.mainContext)
    }

}
