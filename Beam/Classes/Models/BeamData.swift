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
    //swiftlint:disable:next large_tuple
    @Published var renamedNote: (noteId: UUID, previousName: String, newName: String) = (UUID.null, "", "")
    var noteAutoSaveService: NoteAutoSaveService
    var linkManager: LinkManager

    var cookies: HTTPCookieStorage
    var documentManager: DocumentManager
    var downloadManager: BeamDownloadManager = BeamDownloadManager()
    var sessionLinkRanker = SessionLinkRanker()
    var clusteringManager: ClusteringManager
    var scope = Set<AnyCancellable>()
    var browsingTreeSender: BrowsingTreeSender?

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
    static var idToTitle: [UUID: String] = [:]
    static var titleToId: [String: UUID] = [:]

    override init() {
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker, candidate: 2, navigation: 0.5, text: 0.8, entities: 0.3)
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
        let treeConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: EnvironmentVariables.BrowsingTree.url,
            dataStoreApiToken: EnvironmentVariables.BrowsingTree.accessToken
        )
        browsingTreeSender = BrowsingTreeSender(config: treeConfig)
        super.init()

        BeamNote.idForNoteNamed = { title in
            guard let id = Self.titleToId[title] else {
                guard let id = self.documentManager.loadDocumentByTitle(title: title)?.id else { return nil }
                Self.titleToId[title] = id
                Self.idToTitle[id] = title
                return id
            }
            return id
        }
        BeamNote.titleForNoteId = { id in
            guard let title = Self.idToTitle[id] else {
                guard let title = self.documentManager.loadDocumentById(id: id)?.title else { return nil }
                Self.titleToId[title] = id
                Self.idToTitle[id] = title
                return title
            }
            return title
        }

        $renamedNote.dropFirst().sink { (noteId, previousName, newName) in
            Self.titleToId.removeValue(forKey: previousName)
            Self.titleToId[newName] = noteId
            Self.idToTitle[noteId] = newName
        }.store(in: &scope)

        updateNoteCount()
        setupSubscribers()
    }

    // swiftlint:disable:next function_body_length
    private func setupSubscribers() {
        $lastChangedElement.sink { element in
            guard let element = element else { return }
            try? GRDBDatabase.shared.append(element: element)
        }.store(in: &scope)

        $tabToIndex.sink { [weak self] tabToIndex in
            guard let self = self,
                  let tabToIndex = tabToIndex else { return }
            var currentId: UInt64?
            var parentId: UInt64?
            (currentId, parentId) = self.clusteringManager.getIdAndParent(tabToIndex: tabToIndex)
            guard let id = currentId else { return }
            self.clusteringManager.addPage(id: id, parentId: parentId, value: tabToIndex)
            LinkStore.shared.visit(link: tabToIndex.url.string, title: tabToIndex.document.title)

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

        downloadManager.$downloads.sink { [weak self] _ in
            self?.objectWillChange.send()
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
            if !today.type.isJournal {
                today.type = BeamNoteType.todaysJournal
            }
            journal.append(today)
        }

        updateJournal(with: 2, and: journal.count)
    }

    func updateJournal(with limit: Int = 0, and fetchOffset: Int = 0) {
        isFetching = true
        let _journal = BeamNote.fetchNotesWithType(documentManager, type: .journal, limit, fetchOffset).compactMap { $0.type.isJournal && !$0.type.isFutureJournal ? $0 : nil }
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
