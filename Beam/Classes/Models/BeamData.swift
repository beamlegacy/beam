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

    static var indexPath: URL { return URL(fileURLWithPath: dataFolder + "/index.beamindex") }
    static var linkStorePath: URL { return URL(fileURLWithPath: dataFolder + "/links.store") }

    init() {
        documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

        do {
            try LinkStore.loadFrom(Self.linkStorePath)
        } catch {
            Logger.shared.logError("Unable to load link store from \(Self.linkStorePath)", category: .search)
        }
        index = Index.loadOrCreate(Self.indexPath)

        cookies = HTTPCookieStorage()

        updateNoteCount()
    }

    func saveData() {
        // save search index
        do {
            Logger.shared.logInfo("Save link store to \(Self.linkStorePath)", category: .search)
            try LinkStore.saveTo(Self.linkStorePath)
        } catch {
            Logger.shared.logError("Unable to save link store to \(Self.linkStorePath)", category: .search)
        }

        // save search index
        do {
            Logger.shared.logInfo("Saving Index to \(Self.indexPath)", category: .search)
            try index.saveTo(Self.indexPath)
        } catch {
            Logger.shared.logError("Unable to save index to \(Self.indexPath)", category: .search)
        }
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
