//
//  AppDelegate.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Cocoa
import SwiftUI
import Combine
import Sentry
import BeamCore
import UUIDKit

#if DEBUG
@objc(BeamApplication)
public class BeamApplication: NSApplication {
    override init() {
        Logger.setup(subsystem: Configuration.bundleIdentifier)
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
#else
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
#endif

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
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

    var didFinishLaunching = false

    let data = AppData.shared

    var cancellableScope = Set<AnyCancellable>()
    var importCancellables = Set<AnyCancellable>()

    static let defaultWindowMinimumSize = CGSize(width: 800, height: 400)
    static let defaultWindowSize = CGSize(width: 1024, height: 768)

    private let networkMonitor = NetworkMonitor()
    @Published public private(set) var isNetworkReachable: Bool = false

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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        defer { didFinishLaunching = true }

        splashScreenWindow?.close()
        splashScreenWindow = nil

        migrateLegacyData()

        // Importing legacy data may fail so make sure the pinned tabs are ok anyway:
        data.currentAccount?.data.resetPinnedTabs()

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
                AppDelegate.main.storeAllWindowsFromCurrentSession()
            }
            NSSetUncaughtExceptionHandler(prevHandler)
        }

        ContentBlockingManager.shared.setup()
        // Setup localPrivateKey
        EncryptionManager.shared.localPrivateKey()
        //TODO: - Remove when everyone has its local links data moved from old db to grdb
        data.setup()

        if deleteAllLocalDataAtStartup {
            self.deleteAllLocalData()
        }
        DispatchQueue.database.async {
            self.data.softDeleteBrowsingTreeStore()
            GRDBDailyUrlScoreStore(daysToKeep: Configuration.DailyUrlStats.daysToKeep).cleanup()
            NoteScorer.shared.cleanup()
        }
        startDisplayingBrowserImportCompletions()

        if !isRunningTests, !restoreSessionAtLaunch() {
            createWindow(frame: nil)
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
        if let account = data.currentAccount {
            self.beamUIMenuGenerator = BeamUITestsMenuGenerator(account: account)
        }
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
        if !isRunningTests {
            let tenMinutes: TimeInterval = 60*10
            FeatureFlags.startUpdate(refreshInterval: tenMinutes)
        }
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
                Task { @MainActor [weak self] in
                    await self?.checkPrivateKey()
                    self?.window?.state.reloadOfflineTabs()
                }
            }
        }.store(in: &cancellableScope)
    }

    // MARK: - Private Key Check
    @MainActor
    func checkPrivateKey() async {
        await data.currentAccount?.checkPrivateKey()
    }

    // MARK: - Web sockets
    func disconnectWebSockets() {
        data.currentAccount?.disconnectWebSockets()
    }

    // MARK: - Database
    @MainActor
    func syncDataWithBeamObject(force: Bool = false,
                                showAlert: Bool = true,
                                _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) throws -> Bool {
        guard let account = data.currentAccount else { return false }
        return try account.syncDataWithBeamObject(force: force, showAlert: showAlert, completionHandler)
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
        self.createWindow(frame: nil)
    }

    @IBAction func newIncognitoWindow(_ sender: Any?) {
        self.createWindow(frame: nil, isIncognito: true)
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
    func createWindow(frame: NSRect?, title: String? = nil, isIncognito: Bool = false, becomeMain: Bool = true) -> BeamWindow? {
        guard let account = data.currentAccount else { return nil }
        guard !account.data.onboardingManager.needsToDisplayOnboard else {
            account.data.onboardingManager.delegate = self
            account.data.onboardingManager.presentOnboardingWindow()
            return nil
        }
        // Create the window and set the content view.
        let window = BeamWindow(
            contentRect: frame ?? CGRect(origin: .zero, size: Self.defaultWindowSize),
            account: account,
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
        return window
    }

    static func minimumSize(for window: NSWindow?) -> CGSize {
        if window is MiniEditorPanel {
            return CGSize(width: MiniEditorPanel.minimumPanelWidth, height: defaultWindowMinimumSize.height)
        } else {
            return defaultWindowMinimumSize
        }
    }

    // MARK: Restoration

    @UserDefault(key: "RestoreSession", defaultValue: true, suiteName: BeamUserDefaults.restoration.suiteName)
    var restoreSession: Bool

    var canRestoreSession = false

    private func restoreSessionAtLaunch() -> Bool {
        let sessionURL = URL(fileURLWithPath: data.dataFolder(fileName: "session.data"))
        canRestoreSession = FileManager.default.fileExists(atPath: sessionURL.path)

        guard canRestoreSession,
              restoreSession,
              !PreferencesManager.isWindowsRestorationPrevented,
              !NSEvent.modifierFlags.contains(.shift) else {
            return false
        }

        return reopenAllWindowsFromLastSession()
    }

    @discardableResult
    func storeAllWindowsFromCurrentSession() -> Bool {
        let windows = self.windows.filter { !$0.state.isIncognito }

        guard !windows.isEmpty else {
            return false
        }

        do {
            let session = try PropertyListEncoder().encode(windows)
            let sessionURL = URL(fileURLWithPath: data.dataFolder(fileName: "session.data"))
            try session.write(to: sessionURL, options: .atomic)
            canRestoreSession = true
            return true
        } catch {
            Logger.shared.logError("Failed to store session. \(error)", category: .general)
            return false
        }
    }

    @discardableResult
    func reopenAllWindowsFromLastSession() -> Bool {
        guard canRestoreSession else { return false }
        do {
            let sessionURL = URL(fileURLWithPath: data.dataFolder(fileName: "session.data"))
            let data = try Data(contentsOf: sessionURL)
            let windows = try PropertyListDecoder().decode([BeamWindow].self, from: data)
            for window in windows {
                self.windows.append(window)
                subscribeToStateChanges(for: window.state)
                window.makeKeyAndOrderFront(nil)
            }
            canRestoreSession = false
        } catch {
            Logger.shared.logError("Failed to restore session. \(error)", category: .general)
            return false
        }
        return !windows.isEmpty
    }

    func deleteSessionData() {
        let sessionURL = URL(fileURLWithPath: data.dataFolder(fileName: "session.data"))
        try? FileManager.default.removeItem(at: sessionURL)
    }

    // MARK: - Tabs
    func applicationWillTerminate(_ aNotification: Notification) {
        guard let data = data.currentAccount?.data else { return }

        guard !skipTerminateMethods else { return }
        // Insert code here to tear down your application
        do {
            try BeamFileDBManager.shared?.purgeUndo()
        } catch {
            Logger.shared.logError("Unable to purge unused files: \(error)", category: .fileDB)
        }
        if Configuration.branchType != .beta && Configuration.branchType != .publicRelease {
            data.clusteringManager.saveOrphanedUrlsAtSessionClose(orphanedUrlManager: data.clusteringOrphanedUrlManager)
        }
        KeychainDailyNoteScoreStore.shared.save()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && didFinishLaunching {
            createWindow(frame: nil)
        }

        return true
    }

    private var splashScreenWindow: SplashScreenWindow?
    private var legacyMigrationProgressText: String = "" {
        didSet {
            splashScreenWindow?.text = legacyMigrationProgressText
        }
    }

    private func migrateLegacyData() {
        BeamAccount.disableSync()
        defer {
            BeamAccount.enableSync()
        }

        if !BeamAccount.hasValidAccount(in: data.accountsPath) {
            splashScreenWindow = SplashScreenWindow()
            splashScreenWindow?.presentWindow()

            self.legacyMigrationProgressText = "Backup existing data"
            BeamData.backup(overrideArchiveName: "Beam Backup before GRDB migration")

            // try to migrate the old databases
            let account: BeamAccount
            let database: BeamDatabase
            do {
                account = try data.createDefaultAccount()
                database = try account.loadDatabase(account.defaultDatabaseId)
            } catch {
                Logger.shared.logError("Cannot migrate legacy data creating a default account failed: \(error)", category: .accountManager)
                return
            }

            let importer = LegacyDataImporter(account: account, database: database) { text in
                DispatchQueue.mainSync {
                    self.legacyMigrationProgressText = text
                }
            }
            do {
                try importer.importAllFrom(path: data.dataFolder())
            } catch {
                Logger.shared.logError("Error during legacy data migration: \(error)", category: .accountManager)
            }
        }
    }

    static func machineSerialNumber() -> String? {
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

        guard let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0) else { fatalError("Can not get serialNumberAsCFString") }

        IOObjectRelease(platformExpert)

        let value = (serialNumberAsCFString.takeRetainedValue() as? String)
        if value?.isEmpty == true {
            return nil
        }
        return value
    }

    private var deleteAllLocalDataAtStartup = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        // We need to migrate the legacy database BEFORE initializing CoreData so that we can access the sqlite store without making a super slow backup
        #if DEBUG
        NSView.classInit
        #endif

        if Persistence.Device.id == nil {
            let uuid: UUID
            if let id = Self.machineSerialNumber() {
                uuid = UUID.v5(name: "https://macosdevice.beamapp.co/\(id)-\(getuid())", namespace: .oid)
            } else {
                uuid = UUID()
            }

            Persistence.Device.id = uuid
        }

        BeamDocument.formatVersionVariant = Information.appVersionAndBuild
        BeamNote.formatVersionVariant = Information.appVersionAndBuild
        BeamNote.resetHistory = { note in
            DispatchQueue.mainSync {
                note.resetCommandManager()
            }
        }

        BeamVersion.setupLocalDevice(Persistence.Device.id)
        BeamData.registerDefaultManagers()

        do {
            try data.loadAccounts()
            try data.setupCurrentAccount()
        } catch {
            Logger.shared.logError("Unable to setup accounts: \(error)", category: .accountManager)
        }
        
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

        _ = data.currentAccount?.data.browsingTreeSender?.groupWait()
        _ = data.currentAccount?.data.browsingTreeStoreManager.groupWait()
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

        let runningDownloads = data.currentAccount?.data.downloadManager.downloadList.runningDownloads ?? []
        if !runningDownloads.isEmpty {
            let alert = buildAlertForDownloadInProgress(runningDownloads)
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }

        if data.currentAccount?.data.importsManager.isImporting ?? false, cancelQuitAlertForImports() == true {
            return .terminateCancel
        }

        // We need to notify all tabs of imminent termination *before* we store the current session.
        for window in windows {
            for tab in window.state.browserTabsManager.tabs {
                tab.appWillClose()
            }
        }

        if storeAllWindowsFromCurrentSession() {
            let restorationEnabled = PreferencesManager.isWindowsRestorationEnabled
            let alternateModifier = NSEvent.modifierFlags.contains(.option)
            restoreSession = (restorationEnabled && !alternateModifier) || (!restorationEnabled && alternateModifier)
        } else {
            restoreSession = false
        }

        //We need to trigger full sync before quitting the app
        //To make it feel more instant, we first close all the windows
        windows.forEach {
            $0.close(terminatingApplication: true)
        }

        //Then start the full sync.
        //As this code is async, but uses at some point the main thread, we could not ."terminateLater"
        //because it will set its RunLoop in the modalPanel mode and that will make dispatch to main queue fail
        //More explanations here: https://www.thecave.com/2015/08/10/dispatch-async-to-main-queue-doesnt-work-with-modal-window-on-mac-os-x
        fullSyncOnQuitStatus = .ongoing
        Task { @MainActor in
            _ = try syncDataWithBeamObject(force: false, showAlert: false)
            Logger.shared.logDebug("Full sync finished. Asking again to quit, without full sync")
            self.fullSyncOnQuitStatus = .done
            NSApp.terminate(nil)
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
    lazy var settingsWindowController = SettingsWindowController(settingsTab: SettingTab.userSettings)
    lazy var privateSettingsWindowController = SettingsWindowController(settingsTab: SettingTab.privateSettings)

    @IBAction private func preferencesMenuItemActionHandler(_ sender: NSMenuItem) {
        guard let account = data.currentAccount else { return }
        guard !account.data.onboardingManager.needsToDisplayOnboard else { return }
        settingsWindowController.show()
    }

    func openPreferencesWindow(to tab: SettingTab) {
        settingsWindowController.show(tab: tab)
    }

    func closePreferencesWindow() {
        settingsWindowController.close()
    }

    @IBAction private func advancedPreferencesMenuItemActionHandler(_ sender: NSMenuItem) {
        guard let account = data.currentAccount else { return }
        guard !account.data.onboardingManager.needsToDisplayOnboard else { return }
        privateSettingsWindowController.show()
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
