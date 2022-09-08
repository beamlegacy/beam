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

public class BeamData: NSObject, ObservableObject, WKHTTPCookieStoreObserver, BeamDocumentSource {
    // Will be removed for multi-account, do not use!
    static let shared = BeamData()

    public static var sourceId: String { "\(Self.self)" }
    var _todaysNote: BeamNote?
    var todaysNote: BeamNote {
        if let note = _todaysNote, note.isTodaysNote {
            return note
        }
        do {
            try setupJournal()
        } catch {
            Logger.shared.logError("BeamData.setupJournal failed, todaysNote will not work: \(error)", category: .general)
        }
        return _todaysNote!
    }
    @Published var journal: [BeamNote] = []
    @Published var journalSet = Set<BeamNote>()
    @Published var noteCount = 0
    @Published var lastChangedElement: BeamElement?
    @Published var lastIndexedElement: BeamElement?
    @Published var showTabStats = false
    @Published var isFetching = false
    @Published var newDay: Bool = false
    @Published private(set) var pinnedTabs: [BrowserTab] = []
    @Published var currentDraggingSession: ExternalDraggingSession?

    @Published var renamedNote: (noteId: UUID, previousName: String, newName: String) = (UUID.null, "", "")
    var noteAutoSaveService: NoteAutoSaveService

    let cookieManager: CookiesManager

    let currentDatabaseChanged = PassthroughSubject<BeamDatabase?, Never>()
    public weak var currentDatabase: BeamDatabase?
    public weak var currentDocumentCollection: BeamDocumentCollection?

    var downloadManager: BeamDownloadManager = BeamDownloadManager()
    let importsManager: ImportsManager = ImportsManager()
    lazy var calendarManager: CalendarManager = {
        let cm = CalendarManager()
        observeCalendarManager(cm)
        return cm
    }()
    var sessionLinkRanker = SessionLinkRanker()
    var clusteringManager: ClusteringManager
    var tabGroupingManager: TabGroupingManager
    var clusteringOrphanedUrlManager: ClusteringOrphanedUrlManager
    var sessionExporter: ClusteringSessionExporter
    var activeSources = ActiveSources()
    var scope = Set<AnyCancellable>()
    var checkForUpdateCancellable: AnyCancellable?
    let sessionId = UUID()
    var browsingTreeSender: BrowsingTreeSender?
    var noteFrecencyScorer: FrecencyScorer
    var versionChecker: VersionChecker
    lazy var onboardingManager = OnboardingManager(analyticsCollector: analyticsCollector)
    private var pinnedTabsManager = PinnedBrowserTabsManager()
    private(set) lazy var pinnedManager: PinnedNotesManager = {
        PinnedNotesManager()
    }()
    let signpost = SignPost("BeamData")
    let analyticsCollector = AnalyticsCollector()

    // TODO: Move to account specific location.
    static var dataFolder: String {
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

        return localDirectory
    }

    // TODO: Move to account specific location.
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

            if !fileName.isEmpty, FileManager.default.fileExists(atPath: directory + "/\(fileName)") {
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

    let objectManager = BeamObjectManager()
    let contactsManager: ContactsManager
    let passwordManager: PasswordManager
    let privateKeySignatureManager: PrivateKeySignatureManager
    let browsingTreeStoreManager: BrowsingTreeStoreManager
    let linkDB: BeamLinkDB

    func registerSyncDelegates() {
        self.contactsManager.registerOnBeamObjectManager(objectManager)
        self.passwordManager.registerOnBeamObjectManager(objectManager)
        self.privateKeySignatureManager.registerOnBeamObjectManager(objectManager)
        //self.browsingTreeStoreManager.registerOnBeamObjectManager(objectManager)
        ((self.noteFrecencyScorer as? ExponentialFrecencyScorer)?.storage as? GRDBNoteFrecencyStorage)?.registerOnBeamObjectManager(objectManager)
        self.linkDB.registerOnBeamObjectManager(objectManager)
    }

    override init() {
        self.contactsManager = ContactsManager(objectManager: objectManager)
        self.passwordManager = PasswordManager(objectManager: objectManager)
        self.privateKeySignatureManager = PrivateKeySignatureManager(objectManager: objectManager)
        self.browsingTreeStoreManager = BrowsingTreeStoreManager(objectManager: objectManager)
        self.linkDB = BeamLinkDB(objectManager: objectManager)

        self.noteFrecencyScorer = ExponentialFrecencyScorer(storage: GRDBNoteFrecencyStorage(objectManager: objectManager))

        LinkStore.shared = LinkStore(linkManager: linkDB)
        NoteScorer.shared = NoteScorer(dailyStorage: KeychainDailyNoteScoreStore.shared)

        clusteringOrphanedUrlManager = ClusteringOrphanedUrlManager(savePath: Self.orphanedUrlsPath)
        sessionExporter = ClusteringSessionExporter()
        tabGroupingManager = TabGroupingManager()
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker, candidate: 2, navigation: 0.5, text: 0.9, entities: 0.3, sessionId: sessionId,
                                              activeSources: activeSources, tabGroupingManager: tabGroupingManager, objectManager: objectManager)
        noteAutoSaveService = NoteAutoSaveService()
        cookieManager = CookiesManager()
        versionChecker = Self.createVersionChecker()

        let treeConfig = BrowsingTreeSenderConfig(
            dataStoreUrl: EnvironmentVariables.BrowsingTree.url,
            dataStoreApiToken: EnvironmentVariables.BrowsingTree.accessToken,
            waitTimeOut: 2.0,
            anonymized: Configuration.branchType != .develop
        )
        browsingTreeSender = BrowsingTreeSender(config: treeConfig, appSessionId: sessionId)
        super.init()
        BeamNote.idForNoteNamed = { [weak self] title in
            guard let collection = self?.currentDocumentCollection,
                  let doc = try? collection.fetchFirst(filters: [.title(title)])
            else { return nil }
            let id = doc.id
            return id
        }
        BeamNote.titleForNoteId = { [weak self] id in
            guard let collection = self?.currentDocumentCollection,
                  let doc = try? collection.fetchFirst(filters: [.id(id)])
            else { return nil }
            let title = doc.title
            return title
        }

        tabGroupingManager.delegate = self
        setupSubscribers()
        configureAutoUpdate()

        analyticsCollector.add(backend: FirebaseAnalyticsBackend())
    }

    private func setupSubscribers() {
        $lastChangedElement.sink { [weak self] element in
            guard let self = self, let element = element else { return }
            self.signpost.begin("lastElementChanged")
            defer { self.signpost.end("lastElementChanged") }
            BeamData.shared.noteLinksAndRefsManager?.appendAsync(element: element) {
                DispatchQueue.main.async {
                    self.lastIndexedElement = element
                    if let note = element.note,
                       note.type == .note,
                       let changed = note.lastChangeType,
                       changed == .text || changed == .tree {
                        self.clusteringManager.noteToAdd.send(note)
                    }
                }
            }
        }.store(in: &scope)

        $newDay.sink { [weak self] newDay in
            guard let self = self else { return }
            if newDay {
                try? self.reloadJournal()
            }
        }.store(in: &scope)

        downloadManager.downloadList.$downloads.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &scope)

        NotificationCenter.default.addObserver(self, selector: #selector(calendarDayDidChange(notification:)),
                                               name: NSNotification.Name.NSCalendarDayChanged, object: nil)

        BeamDocumentCollection.documentSaved.receive(on: DispatchQueue.main)
            .sink { [weak self] document in
                guard let self = self,
                      document.database == self.currentDatabase
                else { return }

                self.signpost.begin("documentSaved", document.titleAndId)
                defer { self.signpost.end("documentSaved") }

                // All notes go through this publisher
                BeamNote.updateNote(self, document)
                switch document.documentType {
                case .note, .tabGroup:
                    break
                case .journal:
                    // Only send journal updates to this one
                    self.maybeInsertInJournal(document)
                }
            }.store(in: &scope)

        BeamDocumentCollection.documentDeleted.receive(on: DispatchQueue.main)
            .sink { [weak self] deletedDocument in
                guard let self = self else { return }
                let scorer = self.noteFrecencyScorer as? ExponentialFrecencyScorer
                let storage = scorer?.storage as? GRDBNoteFrecencyStorage
                storage?.remoteSoftDelete(noteId: deletedDocument.id)

                guard deletedDocument.database == self.currentDatabase else { return }

                self.signpost.begin("documentDeleted")
                defer { self.signpost.end("documentDeleted") }

                self.clusteringManager.removeNote(noteId: deletedDocument.id)

                self.maybeRemoveFromJournal(deletedDocument)
                BeamNote.purgeDeletedNode(self, deletedDocument.id)
            }.store(in: &scope)

        PreferencesManager.$alwaysShowBullets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alwaysShowBullets in
                guard let collection = BeamData.shared.currentDocumentCollection else { return }
                let allDocuments = (try? collection.fetch(filters: [.isPublic(true)])) ?? []

                var allPublicNotes: [BeamNote] = []
                let newBulletVisibility: BulletPointType = alwaysShowBullets ? .regular : .empty
                for document in allDocuments {
                    guard let note = BeamNote.getFetchedNote(document.id), note.publicationStatus.isPublic else { continue }
                    note.noteSettings?.bulletPointVisibility = newBulletVisibility
                    allPublicNotes.append(note)
                }

                guard let fileManager = self?.fileDBManager else { return }
                allPublicNotes.forEach { note in
                    BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, publicationGroups: note.publicationStatus.publicationGroups, fileManager: fileManager)
                }
        }.store(in: &scope)
    }

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

    func setupJournal(firstSetup: Bool = false) throws {
        guard (!firstSetup || _todaysNote == nil) else { return }

        journal.removeAll()
        journalSet.removeAll()

        let note = try BeamNote.fetchOrCreateJournalNote(self, date: BeamDate.now)
        appendToJournal([note], fetchEvents: !firstSetup)
        _todaysNote = note
        loadMorePastJournalNotes(count: 4, fetchEvents: !firstSetup)
    }

    func deleteJournal() {
        _todaysNote = nil
        journal.removeAll()
        journalSet.removeAll()
        calendarManager.meetingsForNote.removeAll()
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
            if fetchEvents, let journalDate = note.type.journalDate {
                loadEvents(for: note.id, for: journalDate)
            }
        }
        let newJournal = journal + _journal
        let sorted = Set(newJournal).sorted { ($0.type.journalDate ?? Date.distantPast) > ($1.type.journalDate ?? Date.distantPast) }
        journal = sorted
        journalSet = Set(sorted)
    }

    func maybeInsertInJournal(_ document: BeamDocument) {
        // update the journal if a note was added or removed and it's not in the future
        if let journalDate = BeamNoteType.dateFrom(journalDateInt: document.journalDate), journalDate <= BeamDate.now {
            let contained = journal.contains(where: { $0.id == document.id })
            if !contained {
                if !journal.contains(where: { $0.id == document.id }),
                   let index = journal.firstIndex(where: { journalDate > ($0.type.journalDate ?? BeamDate.now) }),
                   let note = BeamNote.fetch(id: document.id) {
                    journal.insert(note, at: index)
                    journalSet.insert(note)
                }
            }
        }
    }

    func maybeRemoveFromJournal(_ document: BeamDocument) {
        if let index = journal.firstIndex(where: { $0.id == document.id }) {
            journalSet.remove(journal[index])
            journal.remove(at: index)
        }
    }

    func updateNoteCount() {
        noteCount = (try? currentDocumentCollection?.count()) ?? 0
    }

    func reloadJournal() throws {
        _todaysNote = nil
        journal.removeAll()
        calendarManager.meetingsForNote.removeAll()
        try setupJournal()
        if newDay { newDay.toggle() }
    }

    public func clearCookiesAndCache() {
        self.cookieManager.clearCookiesAndCache()
    }

    func setup(webView: WKWebView) {
        cookieManager.setupCookies(for: webView)
    }

    ///Create a .zip backup of all the content of the BeamData folder in Beam sandbox
    static func backup(overrideArchiveName: String? = nil) {
        let fileManager = FileManager.default

        guard PreferencesManager.isDataBackupOnUpdateOn else { return }

        let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var archiveName = overrideArchiveName ?? "Beam data archive"

        if let name = overrideArchiveName ?? Information.appName, let version = Information.appVersion, let build = Information.appBuild {
            archiveName = "\(name) v.\(version)_\(build) data backup"
        }

        try? fileManager.zipItem(at: URL(fileURLWithPath: dataFolder(fileName: "")), to: downloadFolder.appendingPathComponent("\(archiveName).zip"), compressionMethod: .deflate)
    }
}

// MARK: - Calendar
extension BeamData {
    private func observeCalendarManager(_ calendarManager: CalendarManager) {
        calendarManager.$updated.sink { [weak self] updated in
            guard let self = self else { return }
            if updated {
                self.reloadAllEvents()
            }
        }.store(in: &scope)
    }

    func reloadAllEvents() {
        if calendarManager.hasConnectedSource() {
            for journal in journal {
                if let journalDate = journal.type.journalDate, !journal.isEntireNoteEmpty() || journal.isTodaysNote {
                    loadEvents(for: journal.id, for: journalDate)
                }
            }
        }
    }

    func refreshEvents(of note: BeamNote) {
        guard note.type.isJournal,
              let futureDate = note.type.journalDate else { return }
        loadEvents(for: note.id, for: futureDate)
    }

    private func loadEvents(for noteUuid: UUID, for journalDate: Date) {
        if calendarManager.hasConnectedSource() {
            self.calendarManager.requestMeetings(for: journalDate, onlyToday: true) { meetings in
                guard let oldMeetings = self.calendarManager.meetingsForNote[noteUuid], oldMeetings == meetings else {
                    self.calendarManager.meetingsForNote[noteUuid] = meetings
                    return
                }
            }
        }
    }
}

// MARK: - AutoUpdate
extension BeamData {
    private static func createVersionChecker() -> VersionChecker {
        let enableUpdateAutoCheck = ![.debug, .test].contains(Configuration.env)
        if let feed = URL(string: Configuration.updateFeedURL) {
            return VersionChecker(feedURL: feed, autocheckEnabled: enableUpdateAutoCheck)
        } else {
            return VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: enableUpdateAutoCheck)
        }
    }

    private func configureAutoUpdate() {

        self.versionChecker.allowAutoDownload = PreferencesManager.isAutoUpdateOn
        self.versionChecker.customPreinstall = {
            Self.backup()
        }
        self.versionChecker.logMessage = { logMessage in
            Logger.shared.logInfo(logMessage, category: .autoUpdate)
        }
        self.versionChecker.customPostinstall = { installed in
            if installed {
                AppDelegate.main.skipTerminateMethods = true
                AppDelegate.main.restoreSession = AppDelegate.main.storeAllWindowsFromCurrentSession()
                NSApp.relaunch()
            }
        }

        advertiseUpdateOnStartup()

        if Configuration.env != .test {
            Task {
                await versionChecker.performUpdateIfAvailable()
            }
        }
    }

    private func advertiseUpdateOnStartup() {
        // Only trigger the startup alert for the beta builds
        guard Configuration.branchType == .beta else { return }

        if versionChecker.autocheckEnabled {
            checkForUpdateCancellable = versionChecker.$state.sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .downloaded(let release):
                    //We need to DispatchAsync here because, if not, the AlertPanel will pause the thread before the state will actually be changed to .downloaded
                    DispatchQueue.main.async {
                        self.showUpdateAlert(onStartUp: true, availableRelease: release.appRelease)
                    }
                default:
                    break
                }
                DispatchQueue.main.async {
                    self.checkForUpdateCancellable = nil
                }
            }
        }
    }

    /// Check for updates right away.
    func checkForUpdate() {
        Task {
            let checkResult = await versionChecker.checkForUpdates()
            DispatchQueue.main.async {
                self.showUpdateAlert(onStartUp: false, availableRelease: checkResult)
            }
        }
    }

    private func showUpdateAlert(onStartUp: Bool, availableRelease: AppRelease?) {
        if onStartUp && availableRelease == nil { return }

        let state = versionChecker.state
        let appName = Information.appName ?? "beam"

        if let release = availableRelease {
            UpdatePanel.showReleaseNoteWindow(with: release, versionChecker: versionChecker)
        } else if state == .noUpdate {
            let updateAlertMessage = "You’re up-to-date!"
            let updateAlertInformativeText = "You are already using the latest version of \(appName)."
            let updateAlertButtonTitle = "OK"

            UserAlert.showMessage(message: updateAlertMessage,
                                  informativeText: updateAlertInformativeText,
                                  buttonTitle: updateAlertButtonTitle) { }
        } else {
            let updateAlertMessage = "Update operation in progress"
            let updateAlertInformativeText = state.informativeMessage
            let updateAlertButtonTitle = "OK"

            UserAlert.showMessage(message: updateAlertMessage,
                                  informativeText: updateAlertInformativeText,
                                  buttonTitle: updateAlertButtonTitle) { }
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

extension BeamData {
    func reindexFileReferences() throws {
        guard let collection = currentDocumentCollection else { throw BeamDataError.currentDatabaseNotSet }
        do {
            try fileDBManager?.clearFileReferences()
            for noteId in try collection.fetchIds(filters: []) {
                guard let note = BeamNote.fetch(id: noteId) else { continue }

                note.visitAllElements { element in
                    guard case let .image(fileId, origin: _, displayInfos: _) = element.kind else { return }
                    do {
                        try self.fileDBManager?.addReference(fromNote: noteId, element: element.id, to: fileId)
                    } catch {
                        Logger.shared.logError("Unable to add reindexed reference to file \(fileId) from element \(element.id) of note \(element.note?.id ?? UUID.null)", category: .fileDB)
                    }
                }
            }
        } catch {
            Logger.shared.logError("Couldn't reindex all files from notes: \(error)", category: .fileDB)
        }
    }
}

// MARK: BeamAccount + BeamDatabase support
extension BeamData {
    func setCurrentDatabase(_ database: BeamDatabase) throws {
        guard currentDatabase != database else { return }
        guard let db = try database.account?.loadDatabase(database.id) else { throw BeamDataError.databaseNotFound }
        currentDatabase = db
        currentDocumentCollection = db.collection
        Persistence.Account.currentDatabaseId = db.id
        currentDatabaseChanged.send(db)

        // We have for now only one current database & account.
        // As tabGroup & file manager do not register on instance creation anymore,
        // this is the good place to register the 2 previous managers on BeamObjectManager
        if let grdbStore = currentDatabase?.grdbStore {
            self.fileDBManager?.grdbStore = grdbStore
        }
        self.fileDBManager?.registerOnBeamObjectManager(objectManager)
        self.tabGroupingManager.storeManager?.registerOnBeamObjectManager(objectManager)

        BeamNote.clearFetchedNotes()

        DispatchQueue.main.async { [weak self] in
            try? self?.reloadJournal()

            let dbID = db.id
            for window in AppDelegate.main.windows where window.state.mode == .note {
                if window.state.currentNote?.databaseId != dbID {
                    window.state.navigateToJournal(note: nil, clearNavigation: true)
                }
            }
        }
    }

    public static func registerDefaultManagers() {
        BeamDatabase.registerManager(BeamDocumentCollection.self)
        BeamDatabase.registerManager(BeamNoteLinksAndRefsManager.self)
        BeamDatabase.registerManager(BeamFileDBManager.self)
        BeamAccount.registerManager(BrowsingTreeDBManager.self)
        BeamAccount.registerManager(TabPinSuggestionDBManager.self)
        BeamAccount.registerManager(UrlStatsDBManager.self)
        BeamAccount.registerManager(UrlHistoryManager.self)
        BeamAccount.registerManager(PasswordsDB.self)
        BeamAccount.registerManager(CreditCardsDB.self)
        BeamAccount.registerManager(MnemonicManager.self)
        BeamAccount.registerManager(ContactsDB.self)
        BeamAccount.registerManager(TabGroupingStoreManager.self)
    }
}

enum BeamDataError: Error {
    case databaseAccountMismatch
    case currentAccountNotSet
    case currentDatabaseNotSet
    case accountNotFound
    case databaseNotFound
    case invalidAccountFile
}

// MARK: - Tab Grouping
extension BeamData: TabGroupingManagerDelegate {
    func allOpenTabsForTabGroupingManager(_ tabGroupingManager: TabGroupingManager, inGroup: TabGroup? = nil) -> [BrowserTab] {
        let tabsManagers = AppDelegate.main.windows.map { $0.state.browserTabsManager }
        return tabsManagers.reduce(into: [BrowserTab]()) { partialResult, tabsManager in
            if let inGroup = inGroup {
                partialResult.append(contentsOf: tabsManager.tabs(inGroup: inGroup))
            } else {
                partialResult.append(contentsOf: tabsManager.tabs)
            }
        }
    }
}
