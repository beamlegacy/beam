//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation
import Combine
import BeamCore

public class BeamData: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    var _todaysNote: BeamNote?
    var todaysNote: BeamNote {
        if let note = _todaysNote, note.title == todaysName {
            return note
        }

        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [BeamNote] = []

    var fileDB: BeamFileDB
    var passwordsDB: PasswordsDB
    @Published var noteCount = 0
    @Published var lastChangedElement: BeamElement?
    @Published var showTabStats = false
    @Published var isFetching = false
    @Published var newDay: Bool = false
    @Published var tabToIndex: TabInformation?
    var noteAutoSaveService: NoteAutoSaveService
    var linkManager: LinkManager

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager
    var downloadManager: DownloadManager = BeamDownloadManager()
    var sessionLinkRanker = SessionLinkRanker()
    var clusteringManager: ClusteringManager
    var scope = Set<AnyCancellable>()
    var browsingTreeSender = BrowsingTreeSender()

    static func dataFolder(fileName: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)

        var name = "BeamData-\(Configuration.env)"
         if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
             Logger.shared.logDebug("Using Gitlab CI Job ID for dataFolder: \(jobId)", category: .general)
            name += "-\(jobId)"
         }

         guard let directory = paths.first else {
             // Never supposed to happen
             return "~/Application Data/BeamApp/"
         }

         let localDirectory = directory + "/Beam" + "/\(name)/"

         do {
             try FileManager.default.createDirectory(atPath: localDirectory,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)

            if FileManager.default.fileExists(atPath: directory + "/\(fileName)") {
                do {
                    try FileManager.default.moveItem(atPath: directory + "/\(fileName)", toPath: localDirectory + fileName)
                } catch {
                    Logger.shared.logError("Unable to move item \(fileName) \(directory) to \(localDirectory): \(error)", category: .general)
                }

            }
             return localDirectory + fileName
         } catch {
             // Does not generate error if directory already exist
             return directory + fileName
         }
     }

    static var indexPath: URL { URL(fileURLWithPath: dataFolder(fileName: "index.beamindex")) }
    static var fileDBPath: String { dataFolder(fileName: "files.db") }
    static var linkStorePath: URL { URL(fileURLWithPath: dataFolder(fileName: "links.store")) }

    override init() {
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker)
        documentManager = DocumentManager()
        noteAutoSaveService = NoteAutoSaveService()
        linkManager = LinkManager()
        passwordsDB = PasswordsManager().passwordsDB
        let linkCount = LinkStore.shared.loadFromDB(linkManager: linkManager)
        Logger.shared.logInfo("Loaded \(linkCount) links from DB", category: .document)
        do {
            try LinkStore.loadFrom(Self.linkStorePath)
        } catch {
            Logger.shared.logError("Unable to load link store from \(Self.linkStorePath)", category: .search)
        }

        do {
            fileDB = try BeamFileDB(path: Self.fileDBPath)
        } catch let error {
            Logger.shared.logError("Error while creating the File Database [\(error)]", category: .fileDB)
            fatalError()
        }

        cookies = HTTPCookieStorage()

        super.init()

        BeamNote.idForNoteNamed = { title in
            self.documentManager.loadDocumentByTitle(title: title)?.id
        }
        BeamNote.titleForNoteId = { id in
            self.documentManager.loadDocumentById(id: id)?.title
        }

        updateNoteCount()
        setupSubscribers()
    }

    private func setupSubscribers() {
        $lastChangedElement.sink { element in
            guard let element = element else { return }
            try? GRDBDatabase.shared.append(element: element)
        }.store(in: &scope)

        $tabToIndex.sink { [weak self] tabToIndex in
            guard let self = self,
                  let tabToIndex = tabToIndex else { return }

            guard var id = tabToIndex.currentTabTree?.current.link else { return }
            var parentId = tabToIndex.parentBrowsingNode?.link
            if let parent = tabToIndex.parentBrowsingNode,
               parent.events.contains(where: { $0.type == .searchBarNavigation }) {
                parentId = nil
            }
            if let current = tabToIndex.currentTabTree?.current,
               current.events.contains(where: { $0.type == .openLinkInNewTab }),
               let tabTree = tabToIndex.tabTree?.current.link {
                parentId = id
                id = tabTree
            }
            if let previousTabTree = tabToIndex.previousTabTree,
               previousTabTree.current.events.contains(where: { $0.type == .openLinkInNewTab }) {
                parentId = previousTabTree.current.link
            }
            self.clusteringManager.addPage(id: id, parentId: parentId, value: tabToIndex)

            // Update history record
            do {
                try GRDBDatabase.shared.insertHistoryUrl(urlId: id,
                                                         url: tabToIndex.url.string,
                                                         title: tabToIndex.document.title,
                                                         content: tabToIndex.textContent)
            } catch {
                Logger.shared.logError("unable to save history url \(tabToIndex.url.string)", category: .search)
            }
        }.store(in: &scope)

        $newDay.sink { [weak self] newDay in
            guard let self = self else { return }
            if newDay {
                self.reloadJournal()
            }
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

    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies({ [weak self] cookies in
            guard let self = self else { return }

            for cookie in cookies {
                self.cookies.setCookie(cookie)
            }
        })
    }

    func setup(webView: WKWebView) {
        for cookie in cookies.cookies ?? [] {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        webView.configuration.websiteDataStore.httpCookieStore.add(self)
    }
}
