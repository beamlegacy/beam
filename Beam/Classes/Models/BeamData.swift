//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation
import Combine
import BeamCore

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
    var indexer: GRDBIndexer
    @Published var noteCount = 0
    @Published var lastChangedElement: BeamElement?
    @Published var showTabStats = false
    @Published var isFetching = false
    @Published var newDay: Bool = false
    var noteAutoSaveService: NoteAutoSaveService
    var linkManager: LinkManager

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager
    var scope = Set<AnyCancellable>()

    static var dataFolder: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return paths.first ?? "~/Application Data/BeamApp/"
    }

    static var indexPath: URL { return URL(fileURLWithPath: dataFolder + "/index.beamindex") }
    static var indexerPath: String { return dataFolder + "/index.beamindexer" }
    static var linkStorePath: URL { return URL(fileURLWithPath: dataFolder + "/links.store") }

    init() {
        documentManager = DocumentManager()
        noteAutoSaveService = NoteAutoSaveService()
        linkManager = LinkManager()
        let linkCount = LinkStore.shared.loadFromDB(linkManager: linkManager)
        Logger.shared.logInfo("Loaded \(linkCount) links from DB", category: .document)
        do {
            try LinkStore.loadFrom(Self.linkStorePath)
        } catch {
            Logger.shared.logError("Unable to load link store from \(Self.linkStorePath)", category: .search)
        }

        index = Index.loadOrCreate(Self.indexPath)

        do {
            indexer = try GRDBIndexer(path: Self.indexerPath)
        } catch {
            Logger.shared.logError("Error while creating the GRDB indexer", category: .search)
            fatalError()
        }

        cookies = HTTPCookieStorage()

        updateNoteCount()

        $lastChangedElement.sink { element in
            guard let element = element else { return }
            try? self.indexer.append(element: element)
        }.store(in: &scope)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(calendarDayDidChange(notification:)),
                                               name: NSNotification.Name.NSCalendarDayChanged,
                                               object: nil)
    }

    func saveData() {
        // save search index
        do {
            Logger.shared.logInfo("Save link store to \(Self.linkStorePath)", category: .search)
            try LinkStore.saveTo(Self.linkStorePath)
        } catch {
            Logger.shared.logError("Unable to save link store to \(Self.linkStorePath): \(error)", category: .search)
        }

        noteAutoSaveService.saveNotes()
        // save search index
        do {
            Logger.shared.logInfo("Saving Index to \(Self.indexPath)", category: .search)
            try index.saveTo(Self.indexPath)
        } catch {
            Logger.shared.logError("Unable to save index to \(Self.indexPath)", category: .search)
        }
    }

    @objc func calendarDayDidChange(notification: Notification) {
        DispatchQueue.main.async {
            self.newDay = true
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

    func reloadJournal() {
        journal = []
        setupJournal()
        if newDay { newDay.toggle() }
    }
}
