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
import PromiseKit
import PMKFoundation
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
        (NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow) as? BeamWindow
    }
    var windows: [BeamWindow] = [] {
        didSet {
            if windows.count == 0 {
                data.allWindowsDidClose()
            }
        }
    }
    var data: BeamData!
    var cancellableScope = Set<AnyCancellable>()
    var importErrorCancellable: AnyCancellable?

    private let defaultWindowMinimumSize = CGSize(width: 800, height: 400)
    private let defaultWindowSize = CGSize(width: 800, height: 600)
    public private(set) lazy var documentManager = DocumentManager()
    public private(set) lazy var databaseManager = DatabaseManager()
    public private(set) lazy var beamObjectManager = BeamObjectManager()

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
            AppDelegate.main.saveCloseTabsCmd(onExit: true)
            NSSetUncaughtExceptionHandler(prevHandler)
        }

        ContentBlockingManager.shared.setup()
        //TODO: - Remove when everyone has its local links data moved from old db to grdb
        BeamObjectManager.setup()

        data = BeamData()
        startDisplayingBrowserImportErrors()

        if !isRunningTests {
            createWindow(frame: nil, restoringTabs: true)
            windows.first?.showUpdateAlert(onStartUp: true)
        }

        Logger.shared.logInfo("This version of Beam was built from a \(EnvironmentVariables.branchType) branch", category: .general)

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logWarning("API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }

        #if DEBUG
        self.beamUIMenuGenerator = BeamUITestsMenuGenerator()
        prepareMenuForTestEnv()

        // In test mode, we want to start fresh without auth tokens as they may have expired
        if Configuration.env == .test {
            AccountManager.logout()
        }
        #endif
        // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
        beamObjectManager.liveSync { _ in
            self.syncDataWithBeamObject()
            self.data.updateNoteCount()
        }
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
    private var openedPrefPanelOnce: Bool = false
    func fixFirstTimeLanuchOddAnimationByImplicitlyShowIt() {
        Preferences.PaneIdentifier.allBeamPreferences.forEach {
            preferencesWindowController.show(preferencePane: $0)
        }
        preferencesWindowController.close()
        openedPrefPanelOnce = true
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

        // With Vinyl and Network test recording, and this executing, it generates async network
        // calls and randomly fails.

        // My feeling is we should sync + trigger notification and only start network calls when
        // this sync has finished.

        let localTimer = BeamDate.now

        do {
            Logger.shared.logInfo("syncAllFromAPI calling", category: .beamObjectNetwork)
            try beamObjectManager.syncAllFromAPI(force: force) { result in
                Logger.shared.logInfo("syncAllFromAPI called",
                                      category: .beamObjectNetwork,
                                      localTimer: localTimer)

                self.deleteEmptyDatabases(showAlert: showAlert) { _ in
                    switch result {
                    case .success:
                        DatabaseManager.changeDefaultDatabaseIfNeeded()
                        completionHandler?(.success(true))
                    case .failure(let error):
                        Logger.shared.logInfo("syncAllFromAPI failed",
                                              category: .beamObjectNetwork,
                                              localTimer: localTimer)
                        completionHandler?(.failure(error))
                    }
                }
            }
        } catch {
            Logger.shared.logError("Couldn't sync beam objects: \(error.localizedDescription)",
                                   category: .document,
                                   localTimer: localTimer)
            completionHandler?(.failure(error))
        }
    }

    private func deleteEmptyDatabases(showAlert: Bool = true,
                                      _ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        let localTimer = BeamDate.now
        let previousDefaultDatabase = DatabaseManager.defaultDatabase

        Logger.shared.logInfo("Deleting Empty databases", category: .database)
        self.databaseManager.deleteEmptyDatabases { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error deleting empty databases: \(error.localizedDescription)",
                                       category: .database,
                                       localTimer: localTimer)
                completionHandler?(.failure(error))
            case .success(let success):
                Logger.shared.logDebug("Deleted Empty databases, success: \(success)",
                                       category: .database,
                                       localTimer: localTimer)
                do {
                    if Configuration.shouldDeleteEmptyDatabase {
                        try self.databaseManager.deleteCurrentDatabaseIfEmpty()
                    }
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .database)
                }

                guard showAlert else {
                    completionHandler?(.success(success))
                    return
                }

                // `DispatchQueue.main.async` doesn't call its block once we called terminate...
                DispatchQueue.main.async { [unowned self] in
                    if previousDefaultDatabase.id != DatabaseManager.defaultDatabase.id {
                        if self.data.onboardingManager.needsToDisplayOnboard == true {
                            Logger.shared.logWarning("Default database changed after onboarding",
                                                    category: .database, localTimer: localTimer)
                        } else {
                            Logger.shared.logWarning("Default database changed, showing alert",
                                                    category: .database, localTimer: localTimer)

                            DatabaseManager.showRestartAlert(previousDefaultDatabase, DatabaseManager.defaultDatabase)
                        }
                    }
                    completionHandler?(.success(success))
                }
            }
        }
    }

    // MARK: -
    // MARK: Windows
    var oauthWindow: OauthWindow?
    func openOauthWindow(title: String?) -> OauthWindow {
        if let oauthWindow = oauthWindow { return oauthWindow }

        oauthWindow = OauthWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 500))
        guard let oauthWindow = oauthWindow else { fatalError("Can't create oauthwindow") }

        if let title = title {
            oauthWindow.title = title
        }
        oauthWindow.center()
        oauthWindow.makeKeyAndOrderFront(window)

        return oauthWindow
    }

    var minimalistWebWindow: NSWindow?
    @discardableResult
    func openMinimalistWebWindow(url: URL, title: String?) -> NSWindow {
        let minWindow = minimalistWebWindow as? MinimalistWebViewWindow ?? MinimalistWebViewWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 500))
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

    @discardableResult
    func createWindow(frame: NSRect?, restoringTabs: Bool) -> BeamWindow? {
        guard !data.onboardingManager.needsToDisplayOnboard else {
            data.onboardingManager.delegate = self
            data.onboardingManager.presentOnboardingWindow()
            return nil
        }
        // Create the window and set the content view.
        let window = BeamWindow(contentRect: frame ?? CGRect(origin: .zero, size: defaultWindowSize),
                                data: data,
                                minimumSize: frame?.size ?? defaultWindowMinimumSize)
        if frame == nil && windows.count == 0 {
            window.center()
        } else {
            if var origin = self.window?.frame.origin {
                origin.x += 20
                origin.y -= 20
                window.setFrameOrigin(origin)
            }
        }
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        subscribeToStateChanges(for: window.state)
        if PreferencesManager.restoreLastBeamSession, restoringTabs {
            window.reOpenClosedTab(nil)
        }
        return window
    }

    // MARK: - Tabs
    func applicationWillTerminate(_ aNotification: Notification) {
        guard !skipTerminateMethods else { return }
        // Insert code here to tear down your application
        do {
            try BeamFileDBManager.shared.purgeUndo()
            try BeamFileDBManager.shared.purgeUnlinkedFiles()
        } catch {
            Logger.shared.logError("Unable to purge unused files: \(error)", category: .fileDB)
        }
        if Configuration.branchType != .beta && Configuration.branchType != .publicRelease {
            data.clusteringManager.saveOrphanedUrls(orphanedUrlManager: data.clusteringOrphanedUrlManager)
        }
        data.clusteringManager.exportSummaryForNextSession()
    }

    public func saveCloseTabsCmd(onExit: Bool) {
        guard windows.contains(where: { $0.state.browserTabsManager.tabs.count > 0}) else { return }
        var windowForTabsCmd = [Int: Command<BeamState>]()
        var windowCount = 0
        let tmpCmdManager = CommandManager<BeamState>()

        for window in windows where window.state.browserTabsManager.tabs.count > 0 {
            tmpCmdManager.beginGroup(with: ClosedTabDataPersistence.closeTabCmdGrp)

            for tab in window.state.browserTabsManager.tabs.reversed() {
                guard !tab.isPinned, tab.url != nil, let index = window.state.browserTabsManager.tabs.firstIndex(of: tab) else { continue }
                let closeTabCmd = CloseTab(tab: tab, appIsClosing: true, tabIndex: index, wasCurrentTab: window.state.browserTabsManager.currentTab === tab)
                // Since we don't run the cmd when closing the app we need to do this out of the CloseTab Cmd
                if onExit {
                    tab.closeApp()
                }
                tmpCmdManager.appendToDone(command: closeTabCmd)
            }
            tmpCmdManager.endGroup(forceGroup: true)

            if let lastCmd = tmpCmdManager.lastCmd {
                windowForTabsCmd[windowCount] = lastCmd
                windowCount += 1
            }
        }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(windowForTabsCmd) else { return }
        if onExit {
            ClosedTabDataPersistence.savedCloseTabData = data
        } else {
            ClosedTabDataPersistence.savedTabsData = data
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && data != nil {
            createWindow(frame: nil, restoringTabs: true)
        }

        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
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

    var documentsWindow: DocumentsWindow?
    var omniboxContentDebuggerWindow: OmniboxContentDebuggerWindow?
    var filesWindow: FilesWindow?
    var databasesWindow: DatabasesWindow?
    var tabGroupingWindow: TabGroupingWindow?

    // MARK: -
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !skipTerminateMethods else { return .terminateNow }
        data.saveData()
        saveCloseTabsCmd(onExit: true)
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

        syncDataWithBeamObject(force: false, showAlert: false) { _ in
            Logger.shared.logDebug("Sending toApplicationShouldTerminate true")
            RunLoop.main.perform(inModes: [.modalPanel]) {
                Logger.shared.logDebug("Sending toApplicationShouldTerminate true (main thread)")
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }

        Logger.shared.logDebug("applicationShouldTerminate: terminateLater")
        return .terminateLater
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
        CardsPreferencesViewController,
        PrivacyPreferencesViewController,
        PasswordsPreferencesViewController,
        AccountsPreferenceViewController,
        AboutPreferencesViewController,
        BetaPreferencesViewController
    ]

    lazy var debugPreferences: [PreferencePane] = [
        GeneralPreferencesViewController,
        BrowserPreferencesViewController,
        CardsPreferencesViewController,
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
            fixFirstTimeLanuchOddAnimationByImplicitlyShowIt()
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
    }

    func applicationWillResignActive(_ notification: Notification) {
        isActive = false
        for window in windows {
            window.state.browserTabsManager.currentTab?.switchToBackground()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if url.pathExtension == BeamDownloadDocument.fileExtension {
            let documentURL = URL(fileURLWithPath: filename)
            if let wrapper = try? FileWrapper(url: documentURL, options: .immediate) {
                do {
                    let doc = try BeamDownloadDocument(fileWrapper: wrapper)
                    doc.fileURL = documentURL
                    try self.data.downloadManager.downloadFile(from: doc)
                } catch {
                    Logger.shared.logError("Can't open Download Document from disk", category: .downloader)
                    return false
                }
                return true
            }
        } else if ["html", "htm"].contains(url.pathExtension) {
            return handleURL(URL(fileURLWithPath: filename))
        }

        return true
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
