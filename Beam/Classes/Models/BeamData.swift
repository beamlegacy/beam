//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation
import Combine

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
    @Published var lastChangedElement: BeamElement?
    @Published var showTabStats = false
    @Published var isFetching = false
    var noteAutoSaveService: NoteAutoSaveService

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager
    var scope = Set<AnyCancellable>()

    static var dataFolder: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return paths.first ?? "~/Application Data/BeamApp/"
    }

    static var indexPath: URL { return URL(fileURLWithPath: dataFolder + "/index.beamindex") }
    static var linkStorePath: URL { return URL(fileURLWithPath: dataFolder + "/links.store") }

    init() {
        documentManager = DocumentManager()
        noteAutoSaveService = NoteAutoSaveService()
        let linkCount = LinkStore.shared.loadFromDB()
        Logger.shared.logInfo("Loaded \(linkCount) links from DB", category: .document)

//        if FileManager.default.fileExists(atPath: Self.linkStorePath.absoluteString) {
//        do {
//            try LinkStore.loadFrom(Self.linkStorePath)
//        } catch {
//            Logger.shared.logError("Unable to load link store from \(Self.linkStorePath)", category: .search)
//        }
//        }
        index = Index.loadOrCreate(Self.indexPath)

        cookies = HTTPCookieStorage()

        updateNoteCount()

        self.$lastChangedElement
            .receive(on: DispatchQueue.main)
            .sink { element in
            guard let element = element else { return }
            guard let note = element.note else { return }

            //BeamNote.detectLinks(self.documentManager)
            element.connectUnlinkedElement(note.title, Array(BeamNote.fetchedNotes.keys))
        }.store(in: &scope)
    }

    func saveData() {
        // save search index
//        do {
//            Logger.shared.logInfo("Save link store to \(Self.linkStorePath)", category: .search)
//            try LinkStore.saveTo(Self.linkStorePath)
//        } catch {
//            Logger.shared.logError("Unable to save link store to \(Self.linkStorePath): \(error)", category: .search)
//        }

        noteAutoSaveService.saveNotes()

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
        if let today = _todaysNote {
            if today.type != .journal {
                today.type = .journal
            }
            journal.append(today)
        }

        updateJournal(with: 2, and: journal.count)
    }

    func updateJournal(with limit: Int = 0, and fetchOffset: Int = 0) {
        isFetching = true
        let _journal = BeamNote.fetchNotesWithType(documentManager, type: .journal, limit, fetchOffset)
        journal.append(contentsOf: _journal)
    }

    func updateNoteCount() {
        noteCount = Document.countWithPredicate(CoreDataManager.shared.mainContext)
    }

}
