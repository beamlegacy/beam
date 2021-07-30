//
//  BeamData.swift
//  Beam
//
//  Created by Sebastien Metrot on 31/10/2020.
//

import Foundation
import Combine
import BeamCore
import AutoUpdate
import ZIPFoundation

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

    var versionChecker: VersionChecker

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
        
        var destinationName = fileName
        if destinationName.hasPrefix("Beam/") {
            destinationName.removeFirst(5)
        }

        do {
            try FileManager.default.createDirectory(atPath: localDirectory,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)

            if FileManager.default.fileExists(atPath: directory + "/\(fileName)") {
                do {
                    try FileManager.default.moveItem(atPath: directory + "/\(fileName)", toPath: localDirectory + destinationName)
                } catch {
                    Logger.shared.logError("Unable to move item \(fileName) \(directory) to \(localDirectory): \(error)", category: .general)
                }
            }
            return localDirectory + destinationName
        } catch {
            // Does not generate error if directory already exist
            return directory + destinationName
        }
    }

    static var indexPath: URL { URL(fileURLWithPath: dataFolder(fileName: "index.beamindex")) }
    static var fileDBPath: String { dataFolder(fileName: "files.db") }
    static var linkStorePath: URL { URL(fileURLWithPath: dataFolder(fileName: "links.store")) }
    static var idToTitle: [UUID: String] = [:]
    static var titleToId: [String: UUID] = [:]

    //swiftlint:disable:next function_body_length
    override init() {
        documentManager = DocumentManager()
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker, documentManager: documentManager, candidate: 2, navigation: 0.5, text: 0.8, entities: 0.3)
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

        if let feed = URL(string: Configuration.updateFeedURL) {
            self.versionChecker = VersionChecker(feedURL: feed, autocheckEnabled: true)
        } else {
            self.versionChecker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: true)
        }
        self.versionChecker.allowAutoDownload = PreferencesManager.isAutoUpdateOn

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
                Self.updateTitleIdNoteMapping(noteId: id, currentName: nil, newName: title)
                return title
            }
            return title
        }

        $renamedNote.dropFirst().sink { (noteId, previousName, newName) in
            Self.updateTitleIdNoteMapping(noteId: noteId, currentName: previousName, newName: newName)
        }.store(in: &scope)

        updateNoteCount()
        setupSubscribers()

        self.versionChecker.customPreinstall = {
            self.backup()
        }
    }

    // swiftlint:disable:next function_body_length
    private func setupSubscribers() {
        $lastChangedElement.sink { element in
            guard let element = element else { return }
            try? GRDBDatabase.shared.append(element: element)
            if let note = element.note,
               note.type == .note,
               let changed = note.changed?.1,
               changed == .text {
                self.clusteringManager.addNote(note: note)
            }
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
        let today = Date()
        return BeamDate.journalNoteTitle(for: today)
    }

    func setupJournal() {
        let note  = BeamNote.fetchOrCreateJournalNote(documentManager, date: Date())
        journal.append(note)
        _todaysNote = note

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

    ///Create a .zip backup of all the content of the BeamData folder in Beam sandbox
    private func backup() {
        let fileManager = FileManager.default

        guard PreferencesManager.isDataBackupOnUpdateOn else { return }

        let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var archiveName = "Beam data archive"

        if let infos = Bundle.main.infoDictionary, let name = infos["CFBundleName"] as? String,
           let version = infos["CFBundleShortVersionString"] as? String, let build = infos["CFBundleVersion"] as? String {
            archiveName = "\(name) v.\(version)_\(build) data backup"
        }

        try? fileManager.zipItem(at: URL(fileURLWithPath: Self.dataFolder(fileName: "")), to: downloadFolder.appendingPathComponent("\(archiveName).zip"), compressionMethod: .deflate)
    }
}

extension BeamData {
    static func updateTitleIdNoteMapping(noteId: UUID, currentName: String?, newName: String?) {
        if let currentName = currentName {
            Self.titleToId.removeValue(forKey: currentName)
        }
        if let newName = newName {
            Self.titleToId[newName] = noteId
            Self.idToTitle[noteId] = newName
        } else {
            Self.idToTitle.removeValue(forKey: noteId)
        }
    }
}
