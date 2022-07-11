//
//  AppDelegate.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//
// swiftlint:disable file_length

import Cocoa
import SwiftUI
import Combine
import Sentry
import Preferences
import BeamCore

@objc(BeamApplication)
public class BeamApplication: SentryCrashExceptionApplication {
    override init() {
        Logger.setup(subsystem: Configuration.bundleIdentifier)
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@NSApplicationMain
// swiftlint:disable type_body_length
class AppDelegate: NSObject, NSApplicationDelegate {
    // swiftlint:disable:next force_cast
    class var main: AppDelegate { NSApplication.shared.delegate as! AppDelegate }

    var skipTerminateMethods = false
    var window: BeamWindow? {
        (NSApplication.shared.keyWindow as? BeamWindow) ?? (NSApplication.shared.mainWindow as? BeamWindow)
    }
    var windows: [BeamWindow] = [] {
        didSet {
            if windows.count == 0 {
                data.allWindowsDidClose()
            }
        }
    }

    var panels: [BeamNote: MiniEditorPanel] = [:]

    var data: BeamData!
    var cancellableScope = Set<AnyCancellable>()
    var importCancellables = Set<AnyCancellable>()

    static let defaultWindowMinimumSize = CGSize(width: 800, height: 400)
    static let defaultWindowSize = CGSize(width: 1024, height: 768)
    public private(set) lazy var beamObjectManager = BeamObjectManager()

    private let networkMonitor = NetworkMonitor()
    @Published public private(set) var isNetworkReachable: Bool = false

    private var synchronizationTask: Task<Void, Error>?
    private let synchronizationTaskQueue = DispatchQueue(label: "SyncTask")
    private var synchronizationSemaphore = DispatchSemaphore(value: 0)
    private var synchronizationSubject = PassthroughSubject<Bool, Never>()
    private(set) var isSynchronizationRunning = false

    var isSynchronizationRunningPublisher: AnyPublisher<Bool, Never> {
        synchronizationSubject.eraseToAnyPublisher()
    }

    #if DEBUG
    var beamUIMenuGenerator: BeamUITestsMenuGenerator!
    #endif

    func resizeWindow(width: CGFloat, height: CGFloat? = nil) {
        var windowRect = window?.frame ?? NSRect(origin: .zero, size: CGSize(width: width, height: height ?? 600))
        windowRect.size.width = width
        windowRect.size.height = height ?? windowRect.size.height
        window?.setFrame(windowRect, display: true)
    }

    var isRunningTests: Bool {
        NSClassFromString("XCTest") != nil
    }

    // swiftlint:disable:next function_body_length
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        splashScreen?.close()
        splashScreen = nil

        data = BeamData()
        let isSwiftUIPreview = NSString(string: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] ?? "0").boolValue
        if Configuration.env.rawValue == "$(ENV)" || Configuration.Sentry.key == "$(SENTRY_KEY)", !isSwiftUIPreview {
            fatalError("The ENV wasn't detected properly, please run `direnv allow` and restart your build. (Should only happen in SwiftUI Previews)")
        }

        if !isSwiftUIPreview {
            setAppearance(BeamAppearance(rawValue: PreferencesManager.beamAppearancePreference))
            DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        }

        ThirdPartyLibrariesManager.shared.configure()
        // We set our own ExceptionHandler but first we get the already set one in that case Sentry
        // We do what we want when there is an exception, in this case saving the tabs then we pass it back to Sentry
        NSSetUncaughtExceptionHandler { _ in
            guard let prevHandler = NSGetUncaughtExceptionHandler() else { return }
            DispatchQueue.mainSync {
                RestoreTabsManager.shared.saveOpenedTabsBeforeTerminatingApp()
            }
            NSSetUncaughtExceptionHandler(prevHandler)
        }

        ContentBlockingManager.shared.setup()
        // Setup localPrivateKey
        EncryptionManager.shared.localPrivateKey()
        //TODO: - Remove when everyone has its local links data moved from old db to grdb
        BeamObjectManager.setup()

        if deleteAllLocalDataAtStartup {
            self.deleteAllLocalData()
        }
        DispatchQueue.global().async {
            BrowsingTreeStoreManager.shared.softDelete(olderThan: 60, maxRows: 20_000)
            GRDBDailyUrlScoreStore(daysToKeep: Configuration.DailyUrlStats.daysToKeep).cleanup()
            NoteScorer.shared.cleanup()
        }
        startDisplayingBrowserImportCompletions()

        if !isRunningTests {
            createWindow(frame: nil, restoringTabs: true)
        }

        Logger.shared.logInfo("This version of Beam was built from a \(EnvironmentVariables.branchType) branch", category: .general)

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logWarning("API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }

        // So we remember we're not currently using the default api server
        if Configuration.restApiHostname != Configuration.restApiHostnameDefault {
            Logger.shared.logWarning("REST API HOSTNAME is \(Configuration.restApiHostname)", category: .general)
        }

        #if DEBUG
        self.beamUIMenuGenerator = BeamUITestsMenuGenerator()
        prepareMenuForTestEnv()

        // In test mode, we want to start fresh without auth tokens as they may have expired
        if Configuration.env == .test {
            data.currentAccount?.logout()
        }
        #endif

        setupNetworkMonitor()

        // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
        data.currentAccount?.updateInitialState()

        fetchTopDomains()
        getUserInfos()
        LoggerRecorder.shared.deleteEntries(olderThan: DateComponents(hour: -2))
    }

    // Work around to fix odd animation in Preferences Panes
    // https://github.com/sindresorhus/Preferences/issues/60
    // I don't like this but couldn't find anything else to fix this issue
    // It means that a full rewrite of the Preferences without the Preferences SPM is needed
    // As soon as the target is 11.0
    // https://developer.apple.com/documentation/swiftui/settings
    var openedPrefPanelOnce: Bool = false
    private func fixFirstTimeLaunchOddAnimationByImplicitlyShowIt() {
        Preferences.PaneIdentifier.allBeamPreferences.forEach {
            preferencesWindowController.show(preferencePane: $0)
        }
        preferencesWindowController.close()
        openedPrefPanelOnce = true
    }

    // MARK: - Network Monitor
    func setupNetworkMonitor() {
        networkMonitor.startListening()
        networkMonitor.networkStatusHandler
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
            switch status {
            case .unknown, .notReachable:
                self?.isNetworkReachable = false
            case .reachable:
                self?.isNetworkReachable = true
                self?.checkPrivateKey()
                self?.window?.state.reloadOfflineTabs()
            }
        }.store(in: &cancellableScope)
    }

    // MARK: - Private Key Check
    func checkPrivateKey() {
        if let account = data.currentAccount {
            if account.checkPrivateKey(useBuiltinPrivateKeyUI: true) == .signedIn {
                beamObjectManager.liveSync { _ in
                    self.syncDataWithBeamObject()
                    self.data.updateNoteCount()
                }
            } else {
                account.logoutIfNeeded()
            }
        }
    }

    // MARK: - Web sockets
    func disconnectWebSockets() {
        beamObjectManager.disconnectLiveSync()
    }

    // MARK: - Database
    func syncDataWithBeamObject(force: Bool = false,
                                showAlert: Bool = true,
                                _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard Configuration.env != .test,
              AuthenticationManager.shared.isAuthenticated,
              Configuration.networkEnabled else {
            completionHandler?(.success(false))
            return
        }

        synchronizationTaskQueue.sync {
            guard isSynchronizationRunning == false else {
                Logger.shared.logDebug("syncTask already running", category: .beamObjectNetwork)
                completionHandler?(.success(false))
                return
            }
            isSynchronizationRunning = true
            synchronizationIsRunningDidUpdate()

            synchronizationSemaphore = DispatchSemaphore(value: 0)
            synchronizationTask = launchSynchronizationTask(force, showAlert, completionHandler)
        }
    }

    private func launchSynchronizationTask(_ force: Bool, _ showAlert: Bool, _ completionHandler: ((Result<Bool, Error>) -> Void)?) -> Task<Void, Error> {
        Task {
            defer {
                self.synchronizationTaskDidStop()
                self.synchronizationSemaphore.signal()
                self.indexAllNotes()
            }

            // swiftlint:disable:next date_init
            let localTimer = Date()
            guard let currentAccount = data.currentAccount else {
                return
            }
            let initialDBs = Set(currentAccount.allDatabases)
            Logger.shared.logInfo("syncAllFromAPI calling", category: .sync)
            do {
                try await beamObjectManager.syncAllFromAPI(force: force,
                                                           prepareBeforeSaveAll: {
                    currentAccount.mergeAllDatabases(initialDBs: initialDBs)
                })
            } catch {
                Logger.shared.logInfo("syncAllFromAPI failed: \(error)",
                                      category: .sync,
                                      localTimer: localTimer)
                completionHandler?(.failure(error))
                return
            }

            Logger.shared.logInfo("syncAllFromAPI called",
                                  category: .sync,
                                  localTimer: localTimer)
            completionHandler?(.success(true))
        }
    }

    public func stopSynchronization() {
        if let task = synchronizationTask {
            task.cancel()
            let semaphoreResult = synchronizationSemaphore.wait(timeout: DispatchTime.now() + .seconds(30))
            if case .timedOut = semaphoreResult {
                Logger.shared.logError("Couldn't cancel synchronization task, timedout", category: .beamObjectNetwork)
            }
        }
    }

    private func synchronizationTaskDidStop() {
        Logger.shared.logInfo("synchronizationTaskDidStop", category: .beamObjectNetwork)
        synchronizationTask = nil
        isSynchronizationRunning = false
        synchronizationIsRunningDidUpdate()
    }

    private func synchronizationIsRunningDidUpdate() {
        synchronizationSubject.send(isSynchronizationRunning)
    }

    private func indexAllNotes() {
        DispatchQueue.main.async {
            BeamNote.indexAllNotes(interactive: false)
        }
    }

    private func deleteEmptyDatabases(showAlert: Bool = true,
                                      _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {

        guard let currentAccount = data.currentAccount else { return }
        do {
            try currentAccount.deleteEmptyDatabases()
            completionHandler?(.success(true))
        } catch {
            Logger.shared.logInfo("deleteEmptyDatabases failed: \(error)",
                                  category: .database)
            completionHandler?(.failure(error))
            return
        }
    }

    // MARK: -
    // MARK: Windows
    var oauthWebViewWindow: OauthWebViewWindow?
    func openOauthWebViewWindow(title: String?) -> OauthWebViewWindow {
        if let oauthWindow = oauthWebViewWindow { return oauthWindow }

        let windowSize = CGSize(width: 600, height: 700)
        oauthWebViewWindow = OauthWebViewWindow(contentRect: CGRect(origin: .zero, size: windowSize))
        oauthWebViewWindow?.setContentSize(windowSize)

        guard let oauthWindow = oauthWebViewWindow else { fatalError("Can't create oauthwindow") }

        if let title = title {
            oauthWindow.title = title
        }
        oauthWindow.center()
        oauthWindow.makeKeyAndOrderFront(window)

        return oauthWindow
    }

    var minimalistWebWindow: NSWindow?
    @discardableResult
    func openMinimalistWebWindow(url: URL, title: String?, rect: CGRect? = nil) -> NSWindow {
        let minWindow = minimalistWebWindow as? MinimalistWebViewWindow ?? MinimalistWebViewWindow(contentRect: rect ?? NSRect(x: 0, y: 0, width: 450, height: 500))
        if let title = title {
            minWindow.title = title
        }
        minWindow.center()
        minWindow.makeKeyAndOrderFront(window)
        minWindow.controller.openURL(url)
        minimalistWebWindow = minWindow
        return minWindow
    }

    @IBAction func newWindow(_ sender: Any?) {
        self.createWindow(frame: nil, restoringTabs: false)
    }

    @IBAction func newIncognitoWindow(_ sender: Any?) {
        self.createWindow(frame: nil, restoringTabs: false, isIncognito: true)
    }

    @discardableResult
    func createWindow(withTabs tabs: [BrowserTab], at location: CGPoint) -> BeamWindow? {
        guard let window = AppDelegate.main.createWindow(frame: nil, title: tabs.first?.title, becomeMain: false) else {
            return nil
        }
        let frameOrigin = CGPoint(x: max(0, location.x - (window.frame.width / 2)),
                                  y: max(0, location.y - window.frame.height + (Toolbar.height / 2)))
        window.setFrameOrigin(frameOrigin)

        tabs.forEach { tab in
            window.state.browserTabsManager.addNewTabAndNeighborhood(tab, setCurrent: true)
        }
        window.state.mode = .web
        window.makeKeyAndOrderFront(nil)
        return window
    }

    @discardableResult
    func createWindow(frame: NSRect?, title: String? = nil, restoringTabs: Bool = false, isIncognito: Bool = false, becomeMain: Bool = true) -> BeamWindow? {
        guard !data.onboardingManager.needsToDisplayOnboard else {
            data.onboardingManager.delegate = self
            data.onboardingManager.presentOnboardingWindow()
            return nil
        }
        // Create the window and set the content view.
        let window = BeamWindow(
            contentRect: frame ?? CGRect(origin: .zero, size: Self.defaultWindowSize),
            data: data,
            title: title,
            isIncognito: isIncognito,
            minimumSize: frame?.size ?? Self.defaultWindowMinimumSize)
        if frame == nil && windows.count == 0 {
            window.center()
        } else {
            if var origin = self.window?.frame.origin {
                origin.x += 20
                origin.y -= 20
                window.setFrameOrigin(origin)
            }
        }
        if becomeMain {
            window.makeKeyAndOrderFront(nil)
        }
        windows.append(window)
        subscribeToStateChanges(for: window.state)
        if PreferencesManager.restoreLastBeamSession, restoringTabs {
            window.reOpenClosedTab(nil)
        }
        return window
    }

    static func minimumSize(for window: NSWindow?) -> CGSize {
        if window is MiniEditorPanel {
            return CGSize(width: MiniEditorPanel.minimumPanelWidth, height: defaultWindowMinimumSize.height)
        } else {
            return defaultWindowMinimumSize
        }
    }

    // MARK: - Tabs
    func applicationWillTerminate(_ aNotification: Notification) {
        guard !skipTerminateMethods else { return }
        // Insert code here to tear down your application
        do {
            try BeamFileDBManager.shared?.purgeUndo()
            try BeamFileDBManager.shared?.purgeUnlinkedFiles()
        } catch {
            Logger.shared.logError("Unable to purge unused files: \(error)", category: .fileDB)
        }
        if Configuration.branchType != .beta && Configuration.branchType != .publicRelease {
            data.clusteringManager.saveOrphanedUrlsAtSessionClose(orphanedUrlManager: data.clusteringOrphanedUrlManager)
        }
        data.clusteringManager.exportSummaryForNextSession()
        KeychainDailyNoteScoreStore.shared.save()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && data != nil {
            createWindow(frame: nil, restoringTabs: false)
        }

        return true
    }

    var deleteAllLocalDataAtStartup = false
    class SplashScreen: NSWindow {
        var nextReport = BeamDate.now
        var text: String = "Migrating orignal data" {
            didSet {
                splashText.stringValue = text

                tick()
            }
        }

        func tick() {
            let now = BeamDate.now
            if nextReport < now {
                RunLoop.main.run(mode: .modalPanel, before: BeamDate.now.addingTimeInterval(0.01))
                nextReport = BeamDate.now.addingTimeInterval(0.2)
            }
        }

        var splashText = NSTextField(labelWithString: "Migrating local database:")

        init() {
            let rect = NSRect(x: 0, y: 0, width: 500, height: 70)
            splashText.stringValue = text
            splashText.isEditable = false
            splashText.isBordered = false
            splashText.alignment = .center
            splashText.isSelectable = false
            splashText.isBezeled = false
            super.init(contentRect: rect, styleMask: [], backing: .buffered, defer: false)
            let title = NSTextField(labelWithAttributedString: NSAttributedString(string: "Migrating local databases:", attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold)]))
            title.alignment = .center
            var iconView: NSImageView?
            if let icon = NSImage(named: Bundle.main.iconFileName ?? "FileDatabase") {
                iconView = NSImageView(image: icon)
            }
            let views = [iconView, title, splashText]
            let stackView = NSStackView(views: views.compactMap({ $0 }))
            stackView.orientation = .vertical
            self.contentView = stackView
            self.isReleasedWhenClosed = false
            self.level = .floating
            self.isOpaque = false
            self.hasShadow = true
        }

    }
    private var splashScreen: SplashScreen?
    var progressText: String = "Migrating orignal data" {
        didSet {
            splashScreen?.text = progressText
        }
    }

    private func migrateLegacyData() {
        BeamAccount.disableSync()
        if !BeamAccount.hasValidAccount(in: BeamData.accountsPath) {
            splashScreen = SplashScreen()
            splashScreen?.center()
            splashScreen?.makeKeyAndOrderFront(nil)
            splashScreen?.orderFrontRegardless()
            splashScreen?.display()
            splashScreen?.update()

            splashScreen?.tick()

            self.progressText = "Backup existing data"
            BeamData.backup(overrideArchiveName: "Beam Backup before GRDB migration")

            // try to migrate the old databases
            let account: BeamAccount
            let database: BeamDatabase
            do {
                account = try BeamData.createDefaultAccount()
                database = try account.loadDatabase(account.defaultDatabaseId)
            } catch {
                Logger.shared.logError("Cannot migrate legacy data creating a default account failed: \(error)", category: .accountManager)
                return
            }

            let importer = LegacyDataImporter(account: account, database: database) { text in
                DispatchQueue.mainSync {
                    self.progressText = text
                }
            }
            do {
                try importer.importAllFrom(path: BeamData.dataFolder)
            } catch {
                Logger.shared.logError("Error during legacy data migration: \(error)", category: .accountManager)
                return
            }
        }

        BeamAccount.enableSync()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // We need to migrate the legacy database BEFORE initializing CoreData so that we can access the sqlite store without making a super slow backup
        BeamData.registerDefaultManagers()

        migrateLegacyData()

        CoreDataManager.shared.setup()

        Logger.shared.logDebug("-------------------------( applicationLaunching )-------------------------",
                                category: .marker)

        // Register for URL opening event
        NSAppleEventManager
            .shared()
            .setEventHandler(
                self,
                andSelector: #selector(handleURLEvent(event:reply:)),
                forEventClass: AEEventClass(kInternetEventClass),
                andEventID: AEEventID(kAEGetURL)
            )

        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), flags.contains(.command), flags.contains(.option), flags.contains(.control) {
            if Persistence.Authentication.email != nil {
                UserAlert.showAlert(message: "Logout from account \(Persistence.emailOrRaiseError())", informativeText: "Do you want to logout?", buttonTitle: "Cancel", secondaryButtonTitle: "Logout", secondaryButtonAction: {
                    self.data.currentAccount?.logout()

                    UserAlert.showAlert(message: "Reset all private keys", informativeText: "Do you want to reset all accounts? (make sure your private keys are backuped first!). The following accounts will be removed:\n\(EncryptionManager.shared.accounts.joined(separator: "\n"))", buttonTitle: "Cancel", secondaryButtonTitle: "Reset all accounts", secondaryButtonAction: {
                        EncryptionManager.shared.resetPrivateKeys(andMigrateOldSharedKey: false)
                    }, style: .critical)
                }, style: .critical)
            }

            UserAlert.showAlert(message: "Erase all local contents", informativeText: "Do you want to eraase all local contents?", buttonTitle: "Cancel", secondaryButtonTitle: "Erase local contents", secondaryButtonAction: {
                self.deleteAllLocalDataAtStartup = true
            }, style: .critical)
        }
    }

    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        Logger.shared.logDebug(userActivity.description, category: .general)

        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return false
        }

        return handleURL(incomingURL)
    }

    var omniboxContentDebuggerWindow: OmniboxContentDebuggerWindow?

    var dataTreeWindow: DataTreeWindow?

    var filesWindow: FilesWindow?
    var tabGroupingWindow: TabGroupingSettingsWindow?
    weak var tabGroupingFeedbackWindow: TabGroupingFeedbackWindow?
    ///Should only be used to say that the full sync on quit is done
    ///Set to true to directly return .terminateNow in shouldTerminate
    var fullSyncOnQuitStatus: FullSyncOnQuitStatus = .notStarted

    // MARK: -
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !skipTerminateMethods, fullSyncOnQuitStatus != .done else { return .terminateNow }
        guard fullSyncOnQuitStatus != .ongoing else {
            Logger.shared.logDebug("Tried to quit while full syncing")
            return .terminateCancel }

        data.currentAccount?.logoutIfNeeded()
        data.saveData()
        RestoreTabsManager.shared.saveOpenedTabsBeforeTerminatingApp()
        _ = self.data.browsingTreeSender?.groupWait()
        _ = BrowsingTreeStoreManager.shared.groupWait()
        // Save changes in the application's managed object context before the application terminates.
        let context = CoreDataManager.shared.mainContext

        if !context.commitEditing() {
            Logger.shared.logDebug("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }

        do {
            try context.save()
        } catch {
            let nserror = error as NSError

            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if result || cancelQuitAlertForSync() {
                return .terminateCancel
            }
        }

        let runningDownloads = data.downloadManager.downloadList.runningDownloads
        if !runningDownloads.isEmpty {
            let alert = buildAlertForDownloadInProgress(runningDownloads)
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }

        if data.importsManager.isImporting, cancelQuitAlertForImports() == true {
            return .terminateCancel
        }

        //We need to trigger full sync before quitting the app
        //To make it feel more instant, we first close all the windows
        windows.forEach {
            $0.close()
        }

        //Then start the full sync.
        //As this code is async, but uses at some point the main thread, we could not ."terminateLater"
        //because it will set its RunLoop in the modalPanel mode and that will make dispatch to main queue fail
        //More explanations here: https://www.thecave.com/2015/08/10/dispatch-async-to-main-queue-doesnt-work-with-modal-window-on-mac-os-x
        fullSyncOnQuitStatus = .ongoing
        syncDataWithBeamObject(force: false, showAlert: false) { _ in
            Logger.shared.logDebug("Full sync finished. Asking again to quit, without full sync")
            DispatchQueue.main.async {
                self.fullSyncOnQuitStatus = .done
                NSApp.terminate(nil)
            }
        }

        //We cancel the quit for now. Will ask again after full sync is over
        return .terminateCancel
    }

    private func cancelQuitAlertForImports() -> Bool {
        let question = NSLocalizedString("We're still importing data", comment: "Quit interrupting import message")
        let info = NSLocalizedString("Are you sure you want to interrupt the process and quit now? You can always import data from the File → Import menu.",
                                     comment: "Quit interrupting import info")
        let quitButton = NSLocalizedString("Quit", comment: "Quit anyway button title")
        let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = info
        alert.addButton(withTitle: quitButton)
        alert.addButton(withTitle: cancelButton)

        let answer = alert.runModal()
        if answer == .alertSecondButtonReturn {
            return true
        }
        return false
    }

    private func cancelQuitAlertForSync() -> Bool {
        let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
        let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info")
        let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
        let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = info
        alert.addButton(withTitle: quitButton)
        alert.addButton(withTitle: cancelButton)

        let answer = alert.runModal()
        if answer == .alertSecondButtonReturn {
            return true
        }
        return false
    }

    // MARK: - Preferences
    lazy var preferences: [PreferencePane] = [
        GeneralPreferencesViewController,
        BrowserPreferencesViewController,
        NotesPreferencesViewController,
        PrivacyPreferencesViewController,
        PasswordsPreferencesViewController,
        AccountsPreferenceViewController,
        AboutPreferencesViewController,
        BetaPreferencesViewController
    ]

    lazy var debugPreferences: [PreferencePane] = [
        GeneralPreferencesViewController,
        BrowserPreferencesViewController,
        NotesPreferencesViewController,
        PrivacyPreferencesViewController,
        PasswordsPreferencesViewController,
        AccountsPreferenceViewController,
        AboutPreferencesViewController,
        BetaPreferencesViewController,
        AdvancedPreferencesViewController,
        EditorDebugPreferencesViewController
    ]

    lazy var preferencesWindowController = PreferencesWindowController(
        preferencePanes: Configuration.branchType == .beta || Configuration.branchType == .publicRelease ? preferences : debugPreferences,
        style: .toolbarItems,
        animated: true,
        hidesToolbarForSingleItem: true
    )

    @IBAction private func preferencesMenuItemActionHandler(_ sender: NSMenuItem) {
        guard !data.onboardingManager.needsToDisplayOnboard else { return }
        if !openedPrefPanelOnce {
            fixFirstTimeLaunchOddAnimationByImplicitlyShowIt()
        }
        preferencesWindowController.show()
    }

    func openPreferencesWindow(to prefPane: Preferences.PaneIdentifier) {
        preferencesWindowController.show(preferencePane: prefPane)
    }

    func closePreferencesWindow() {
        preferencesWindowController.close()
    }

    func applicationWillHide(_ notification: Notification) {
        CustomPopoverPresenter.shared.dismissPopovers(animated: false)
        for window in windows {
            window.state.browserTabsManager.currentTab?.switchToBackground()
        }
    }

    func applicationDidUnhide(_ notification: Notification) {
        for window in windows where window.isMainWindow {
            window.state.browserTabsManager.currentTab?.tabDidAppear(withState: window.state)
        }
    }

    public var isActive = false

    func applicationDidBecomeActive(_ notification: Notification) {
        isActive = true
        for window in windows where window.isMainWindow {
            guard window.state.mode == .web else { continue }
            window.state.browserTabsManager.currentTab?.tabDidAppear(withState: window.state)
        }
        ContentBlockingManager.shared.synchronizeIfNeeded()
        showTagGroupingFeedbackIfNeeded()
    }

    func applicationWillResignActive(_ notification: Notification) {
        isActive = false
        for window in windows {
            window.state.browserTabsManager.currentTab?.switchToBackground()
        }
        checkAndRepairLinkDBIfNeeded()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard !ProcessInfo().arguments.contains(Configuration.uiTestModeLaunchArgument) else {
            return true
        }
        return handleOpenFileURL(URL(fileURLWithPath: filename))
    }

}

// MARK: - Full sync on quit
extension AppDelegate {
    enum FullSyncOnQuitStatus {
        case notStarted
        case ongoing
        case done
    }
}

// MARK: - NSAppearance
extension AppDelegate {
    @objc
    func interfaceModeChanged(sender: NSNotification) {
        if BeamAppearance(rawValue: PreferencesManager.beamAppearancePreference) == BeamAppearance.system {
            setAppearance(getSystemAppearance())
        }
    }

    func getSystemAppearance() -> BeamAppearance {
        let mode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return mode == "Dark" ? BeamAppearance.dark : BeamAppearance.light
    }

    func setAppearance(_ appearance: BeamAppearance?) {
        guard let appearance = appearance else { return }
        switch appearance {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .system:
            setAppearance(getSystemAppearance())
        }
    }
}

// MARK: - Downloads
extension AppDelegate {

    fileprivate func buildAlertForDownloadInProgress(_ downloads: [DownloadItem]) -> NSAlert {
        let message: String
        let question: String

        if let uniqueDownload = downloads.first, downloads.count == 1 {
            question = NSLocalizedString("A download is in progress", comment: "Quit during download")
            message = """
                        Are you sure you want to quit? Beam is currently downloading "\(uniqueDownload.filename ?? "")".
                        If you quit now, Beam won’t finish downloading this file.
                        """
        } else {
            question = NSLocalizedString("Downloads are in progress", comment: "Quit during downloads")
            message = """
                        Are you sure you want to quit? Beam is currently downloading \(downloads.count) files.
                        If you quit now, Beam won’t finish downloading these files.
                        """
        }

        let alert = NSAlert()

        let info = NSLocalizedString(message, comment: "Quit with download message")
        let quitButton = NSLocalizedString("Quit", comment: "Quit button title")
        let cancelButton = NSLocalizedString("Don't quit", comment: "Don't quit button title")
        alert.messageText = question
        alert.informativeText = info
        alert.addButton(withTitle: quitButton)
        alert.addButton(withTitle: cancelButton)
        return alert
    }
}
