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

// swiftlint:disable file_length
public class BeamData: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    var _todaysNote: BeamNote?
    var todaysNote: BeamNote {
        if let note = _todaysNote, note.isTodaysNote {
            return note
        }
        setupJournal()
        return _todaysNote!
    }
    @Published var journal: [BeamNote] = []
    @Published var noteCount = 0
    @Published var lastChangedElement: BeamElement?
    @Published var lastIndexedElement: BeamElement?
    @Published var showTabStats = false
    @Published var isFetching = false
    @Published var newDay: Bool = false
    @Published var tabToIndex: TabInformation?
    @Published private(set) var pinnedTabs: [BrowserTab] = []
    //swiftlint:disable:next large_tuple
    @Published var renamedNote: (noteId: UUID, previousName: String, newName: String) = (UUID.null, "", "")
    var noteAutoSaveService: NoteAutoSaveService

    var cookies: HTTPCookieStorage
    var downloadManager: BeamDownloadManager = BeamDownloadManager()
    var importsManager: ImportsManager = ImportsManager()
    lazy var calendarManager: CalendarManager = {
        let cm = CalendarManager()
        observeCalendarManager(cm)
        return cm
    }()
    var sessionLinkRanker = SessionLinkRanker()
    var clusteringManager: ClusteringManager
    var clusteringOrphanedUrlManager: ClusteringOrphanedUrlManager
    var activeSources = ActiveSources()
    var scope = Set<AnyCancellable>()
    let sessionId = UUID()
    var browsingTreeSender: BrowsingTreeSender?
    var noteFrecencyScorer: FrecencyScorer = ExponentialFrecencyScorer(storage: GRDBNoteFrecencyStorage())
    var versionChecker: VersionChecker
    var onboardingManager = OnboardingManager()
    private var pinnedTabsManager = PinnedBrowserTabsManager()
    let signpost = SignPost("BeamData")

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
    static var orphanedUrlsPath: URL { URL(fileURLWithPath: dataFolder(fileName: "clusteringOrphanedUrlsWithNavigation.csv")) }
    static var fileDBPath: String { dataFolder(fileName: "files.db") }
    static var linkDBPath: String { dataFolder(fileName: "links.db") }
    static var idToTitle: [UUID: String] = [:]
    static var titleToId: [String: UUID] = [:]

    //swiftlint:disable:next function_body_length
    override init() {
        LinkStore.shared = LinkStore(linkManager: BeamLinkDB.shared)
        clusteringOrphanedUrlManager = ClusteringOrphanedUrlManager(savePath: Self.orphanedUrlsPath)
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker, candidate: 2, navigation: 0.5, text: 0.9, entities: 0.4, sessionId: sessionId, activeSources: activeSources)
        noteAutoSaveService = NoteAutoSaveService()
        cookies = HTTPCookieStorage()

        let enableUpdateAutoCheck = Configuration.env != .debug
        if let feed = URL(string: Configuration.updateFeedURL) {
            self.versionChecker = VersionChecker(feedURL: feed, autocheckEnabled: enableUpdateAutoCheck)
        } else {
            self.versionChecker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: enableUpdateAutoCheck)
        }

        let treeConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: EnvironmentVariables.BrowsingTree.url,
            dataStoreApiToken: EnvironmentVariables.BrowsingTree.accessToken,
            waitTimeOut: 2.0
        )
        browsingTreeSender = BrowsingTreeSender(config: treeConfig, appSessionId: sessionId)
        super.init()

        let documentManager = DocumentManager()

        BeamNote.idForNoteNamed = { title, includeDeletedNotes in
            guard let doc = documentManager.loadDocumentByTitle(title: title),
                  includeDeletedNotes || doc.deletedAt == nil
            else { return nil }
            let id = doc.id
            return id
        }
        BeamNote.titleForNoteId = { id, includeDeletedNotes in
            guard let doc = documentManager.loadDocumentById(id: id, includeDeleted: includeDeletedNotes)
            else { return nil }
            let title = doc.title
            return title
        }

        setupSubscribers()
        resetPinnedTabs()
        configureAutoUpdate()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func setupSubscribers() {
        $lastChangedElement.sink { [weak self] element in
            guard let self = self, let element = element else { return }
            self.signpost.begin("lastElementChanged")
            defer { self.signpost.end("lastElementChanged") }
            GRDBDatabase.shared.appendAsync(element: element) {
                DispatchQueue.main.async {
                    self.lastIndexedElement = element
                    if let note = element.note,
                       note.type == .note,
                       let changed = note.lastChangeType,
                       changed == .text || changed == .tree {
                        self.clusteringManager.noteToAdd = note
                    }
                }
            }
        }.store(in: &scope)

        $tabToIndex.sink { [weak self] tabToIndex in
            guard let self = self,
                  let tabToIndex = tabToIndex else { return }
            self.signpost.begin("indexTab")
            defer { self.signpost.end("indexTab") }
            var currentId: UUID?
            var parentId: UUID?
            (currentId, parentId) = self.clusteringManager.getIdAndParent(tabToIndex: tabToIndex)
            guard let id = currentId else { return }
            if tabToIndex.shouldBeIndexed {
                self.clusteringManager.addPage(id: id, parentId: parentId, value: tabToIndex)
                _ = LinkStore.shared.visit(tabToIndex.url.string, title: tabToIndex.document.title, content: tabToIndex.textContent)
            }

            // Update history record
//            do {
//                if tabToIndex.shouldBeIndexed {
//                    try GRDBDatabase.shared.insertHistoryUrl(urlId: id,
//                                                             url: tabToIndex.url.string,
//                                                             aliasDomain: tabToIndex.requestedUrl?.absoluteString,
//                                                             title: tabToIndex.document.title,
//                                                             content: nil)
//                }
//            } catch {
//                Logger.shared.logError("unable to save history url \(tabToIndex.url.string)", category: .search)
//            }
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

        NotificationCenter.default.addObserver(self, selector: #selector(calendarDayDidChange(notification:)),
                                               name: NSNotification.Name.NSCalendarDayChanged, object: nil)

        DocumentManager.documentSaved.receive(on: DispatchQueue.main)
            .sink { [weak self] documentStruct in
                guard let self = self else { return }
                self.signpost.begin("documentSaved", documentStruct.titleAndId)
                defer { self.signpost.end("documentSaved") }

                // All notes go through this publisher
                BeamNote.updateNote(documentStruct)
                Self.noteUpdated.send(documentStruct)
                switch documentStruct.documentType {
                case .note:
                    if documentStruct.deletedAt != nil {
                        self.clusteringManager.removeNote(noteId: documentStruct.id)
                        self.activeSources.removeNote(noteId: documentStruct.id)
                    }
                case .journal:
                    // Only send journal updates to this one
                    Self.journalNoteUpdated.send(documentStruct)

                    // Also update the journal if a note was added or removed and it's not in the future
                    if let journalDateString = documentStruct.journalDate, let journalDate = BeamNoteType.dateFormater.date(from: journalDateString), journalDate <= BeamDate.now {
                        let contained = self.journal.contains(where: { $0.id == documentStruct.id })
                        let added = documentStruct.deletedAt == nil && !contained
                        let removed = documentStruct.deletedAt != nil && contained

                        if added {
                            if !self.journal.contains(where: { $0.id == documentStruct.id }),
                               let index = self.journal.firstIndex(where: { journalDate > ($0.type.journalDate ?? BeamDate.now) }),
                               let note = BeamNote.fetch(id: documentStruct.id, includeDeleted: false) {
                                self.journal.insert(note, at: index)
                            }
                        } else if removed {
                            if let index = self.journal.firstIndex(where: { $0.id == documentStruct.id }) {
                                self.journal.remove(at: index)
                            }
                        }
                    }
                }
            }.store(in: &scope)

        DocumentManager.documentDeleted.receive(on: DispatchQueue.main)
            .sink { id in
                self.signpost.begin("documentDeleted")
                defer { self.signpost.end("documentDeleted") }
                if let index = self.journal.firstIndex(where: { $0.id == id }) {
                    self.journal.remove(at: index)
                }
                BeamNote.purgeDeletedNode(id)
            }.store(in: &scope)
    }

    static let noteUpdated = PassthroughSubject<DocumentStruct, Never>()
    static let journalNoteUpdated = PassthroughSubject<DocumentStruct, Never>()

    func allWindowsDidClose() {
        resetPinnedTabs()
    }

    func saveData() {
        noteAutoSaveService.saveNotes()
    }

    @objc func calendarDayDidChange(notification: Notification) {
        DispatchQueue.main.async {
            self.newDay = true
        }
    }

    var todaysName: String {
        let today = BeamDate.now
        return BeamDate.journalNoteTitle(for: today)
    }

    private var journalCancellables = [AnyCancellable]()
    private func observeJournal(note: BeamNote) {
        note.$deleted
            .drop(while: { $0 == true }) // skip notes that started already deleted
            .sink { [unowned self] deleted in
                if deleted {
                    self.reloadJournal()
                }
            }.store(in: &journalCancellables)
    }

    func setupJournal(firstSetup: Bool = false) {
        journalCancellables = []
        journal.removeAll()
        let note  = BeamNote.fetchOrCreateJournalNote(date: BeamDate.now)
        observeJournal(note: note)
        journal.append(note)
        _todaysNote = note
        loadMorePastJournalNotes(count: 4, fetchEvents: !firstSetup)
    }

    func loadMorePastJournalNotes(count: Int, fetchEvents: Bool) {
        isFetching = true
        guard let earliest = journal.last,
              let earliestDateString = earliest.type.journalDateString
        else {
            Logger.shared.logError("Unable to find ealiest journal note or date", category: .general)
            return
        }

        var date = earliestDateString
        var _journal = [BeamNote]()
        var todo = count
        // Try to find a journal note that is earlier that the last entry and that is not empty
        var shouldAppear = false
        repeat {
            let notes = BeamNote.fetchJournalsBefore(count: 1, date: date)
            guard !notes.isEmpty else { break }
            _journal.append(contentsOf: notes)
            date = _journal.last?.type.journalDateString ?? ""
            shouldAppear = _journal.last?.shouldAppearInJournal ?? false
            todo -= (shouldAppear ? 1 : 0)
        } while todo > 0

        appendToJournal(_journal, fetchEvents: fetchEvents)
    }

    func loadJournalUpTo(date: String) {
        let _journal = BeamNote.fetchJournalsFrom(date: date)
        appendToJournal(_journal, fetchEvents: true)
    }

    func appendToJournal(_ _journal: [BeamNote], fetchEvents: Bool) {
        for note in _journal {
            observeJournal(note: note)
            if fetchEvents, let journalDate = note.type.journalDate {
                loadEvents(for: note.id, for: journalDate)
            }
        }
        let newJournal = journal + _journal
        let sorted = Set(newJournal).sorted { ($0.type.journalDate ?? Date.distantPast) > ($1.type.journalDate ?? Date.distantPast) }
        journal = sorted
    }

    func updateNoteCount() {
        noteCount = DocumentManager().count()
    }

    func reloadJournal() {
        journal.removeAll()
        calendarManager.meetingsForNote.removeAll()
        setupJournal()
        if newDay { newDay.toggle() }
    }

    private func observeCalendarManager(_ calendarManager: CalendarManager) {
        calendarManager.$updated.sink { [weak self] updated in
            guard let self = self else { return }
            if updated {
                self.reloadAllEvents()
            }
        }.store(in: &scope)
    }

    func reloadAllEvents() {
        if calendarManager.isConnected(calendarService: .googleCalendar) {
            for journal in journal {
                if let journalDate = journal.type.journalDate, !journal.isEntireNoteEmpty() || journal.isTodaysNote {
                    loadEvents(for: journal.id, for: journalDate)
                }
            }
        }
    }

    private func loadEvents(for noteUuid: UUID, for journalDate: Date) {
        if calendarManager.isConnected(calendarService: .googleCalendar) {
            self.calendarManager.requestMeetings(for: journalDate, onlyToday: true) { meetings in
                guard let oldMeetings = self.calendarManager.meetingsForNote[noteUuid], oldMeetings == meetings else {
                    self.calendarManager.meetingsForNote[noteUuid] = meetings
                    return
                }
            }
        }
    }

    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies({ [weak self] cookies in
            guard let self = self else { return }

            for cookie in cookies {
                self.cookies.setCookie(cookie)
            }
        })
    }

    public func clearCookiesAndCache() {
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), completionHandler: { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        })
    }

    func setup(webView: WKWebView) {
        let configuration = webView.configurationWithoutMakingCopy
        for cookie in cookies.cookies ?? [] {
            configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        configuration.websiteDataStore.httpCookieStore.add(self)
    }

    ///Create a .zip backup of all the content of the BeamData folder in Beam sandbox
    private func backup() {
        let fileManager = FileManager.default

        guard PreferencesManager.isDataBackupOnUpdateOn else { return }

        let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var archiveName = "Beam data archive"

        if let name = Information.appName, let version = Information.appVersion, let build = Information.appBuild {
            archiveName = "\(name) v.\(version)_\(build) data backup"
        }

        try? fileManager.zipItem(at: URL(fileURLWithPath: Self.dataFolder(fileName: "")), to: downloadFolder.appendingPathComponent("\(archiveName).zip"), compressionMethod: .deflate)
    }

    private func configureAutoUpdate() {

        self.versionChecker.allowAutoDownload = PreferencesManager.isAutoUpdateOn
        self.versionChecker.customPreinstall = {
            self.backup()
        }
        self.versionChecker.logMessage = { logMessage in
            Logger.shared.logInfo(logMessage, category: .autoUpdate)
        }
    }
}

// MARK: - Default Browser
public extension BeamData {
    // Looked at how chromium does it in their third_party/mozilla/NSWorkspace+Utils.m file
    static var installedBrowserURLs: [URL] {
        var apps = [URL]()
        if let url = URL(string: "http://beamapp.co"),
           let handlers = LSCopyApplicationURLsForURL(url as CFURL, .viewer)?.takeRetainedValue() {
            if let array = handlers as [AnyObject] as? [URL] {
                apps = array
            }
        }
        // add the default if it isn't there
        if let defaultHandler = defaultBrowserURL, !apps.contains(defaultHandler) {
            apps.append(defaultHandler)
        }
        return apps
    }

    static var defaultBrowserURL: URL? {
        guard let url = URL(string: "http://beamapp.co"),
              let defaultBundleURL = LSCopyDefaultApplicationURLForURL(url as CFURL, .viewer, nil)?.takeRetainedValue() else {
            // Sometimes LaunchServices likes to pretend there's no default browser.
            // If that happens, we'll assume it's probably Safari.
            return nil
        }
        return defaultBundleURL as URL
    }

    static var isDefaultBrowser: Bool {
        Self.defaultBrowserURL == Bundle.main.bundleURL
    }

    @discardableResult
    static func setAsMainBrowser() -> Bool {
        guard let _bundleID = Bundle.main.bundleIdentifier else {
            Logger.shared.logError("Unable to get main bundle id to set Beam as the default browser", category: .general)
            return false
        }
        setMainBrowser(bundleID: _bundleID)
        return true
    }

    static func setSafariAsMainBrowser() {
        setMainBrowser(bundleID: "com.apple.safari")
    }

    static func setMainBrowser(bundleID _bundleID: String) {
        let bundleID = _bundleID as CFString
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID)
        LSSetDefaultRoleHandlerForContentType(kUTTypeHTML, .viewer, bundleID)
        LSSetDefaultRoleHandlerForContentType(kUTTypeURL, .viewer, bundleID)
    }
}

// MARK: - Pinned Tab
extension BeamData {
    func savePinnedTabs(_ tabs: [BrowserTab]) {
        pinnedTabs = tabs
        pinnedTabsManager.savePinnedTabs(tabs: tabs)
    }

    func resetPinnedTabs() {
        pinnedTabs = pinnedTabsManager.getPinnedTabs()
    }
}
