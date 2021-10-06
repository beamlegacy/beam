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
class AppDelegate: NSObject, NSApplicationDelegate {
    // swiftlint:disable:next force_cast
    class var main: AppDelegate { NSApplication.shared.delegate as! AppDelegate }

    var window: BeamWindow? {
        (NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow) as? BeamWindow
    }
    var windows: [BeamWindow] = []
    var data: BeamData!

    var cancellableScope = Set<AnyCancellable>()

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
        if Configuration.env == "$(ENV)", !isSwiftUIPreview {
            fatalError("Please restart your build, your ENV wasn't detected properly, and this should only happens for SwiftUI Previews")
        }

        if !isSwiftUIPreview {
            setAppearance(BeamAppearance(rawValue: PreferencesManager.beamAppearancePreference))
            DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        }

        LibrariesManager.shared.configure()
        ContentBlockingManager.shared.setup()
        BeamObjectManager.setup()

        data = BeamData()

        if !isRunningTests {
            createWindow(frame: nil)
        }

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logWarning("API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }

        #if DEBUG
        self.beamUIMenuGenerator = BeamUITestsMenuGenerator()
        prepareMenuForTestEnv()
        #endif

        // We sync data *after* we potentially connected to websocket, to make sure we don't miss any data
        beamObjectManager.liveSync { _ in
            self.syncDataWithBeamObject()
        }
        fetchTopDomains()
        getUserInfos()
    }

    // MARK: - Web sockets
    func disconnectWebSockets() {
        beamObjectManager.disconnectLiveSync()
    }

    // MARK: -
    // MARK: Oauth window
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

    func syncDataWithBeamObject(_ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
        guard Configuration.env != "test",
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
            try beamObjectManager.syncAllFromAPI { result in
                self.deleteEmptyDatabases { _ in
                    switch result {
                    case .success:
                        Logger.shared.logInfo("syncAllFromAPI called", category: .beamObjectNetwork, localTimer: localTimer)
                        DatabaseManager.changeDefaultDatabaseIfNeeded()
                        completionHandler?(.success(true))
                    case .failure(let error):
                        Logger.shared.logInfo("syncAllFromAPI failed", category: .beamObjectNetwork, localTimer: localTimer)
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

    private func deleteEmptyDatabases(_ completionHandler: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
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
                Logger.shared.logDebug("Deleted Empty databases, success: \(success)", category: .database)
                do {
                    if Configuration.shouldDeleteEmptyDatabase {
                        try self.databaseManager.deleteCurrentDatabaseIfEmpty()
                    }
                } catch {
                    Logger.shared.logError(error.localizedDescription, category: .database)
                }
                if previousDefaultDatabase.id != DatabaseManager.defaultDatabase.id {
                    Logger.shared.logWarning("Default database changed, showing alert",
                                             category: .database,
                                             localTimer: localTimer)
                    DatabaseManager.showRestartAlert(previousDefaultDatabase,
                                                     DatabaseManager.defaultDatabase)
                }
                completionHandler?(.success(success))
            }
        }
    }

    @IBAction func newWindow(_ sender: Any?) {
        self.createWindow(frame: nil)
    }

    @discardableResult
    func createWindow(frame: NSRect?) -> BeamWindow {
        // Create the window and set the content view.
        let window = BeamWindow(contentRect: frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
                                data: data)
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
        return window
    }

    static let closeTabCmdGrp = "CloseTabCmdGrp"
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        saveCloseTabsCmd()
        data.clusteringManager.saveOrphanedUrls(orphanedUrlManager: data.clusteringOrphanedUrlManager)
    }

    private func saveCloseTabsCmd() {
        var windowForTabsCmd = [Int: Command<BeamState>]()
        var windowCount = 0

        for window in windows where window.state.browserTabsManager.tabs.count > 0 {
            window.state.cmdManager.beginGroup(with: AppDelegate.closeTabCmdGrp)

            for tab in window.state.browserTabsManager.tabs {
                let closeTabCmd = CloseTab(tab: tab, appIsClosing: true)
                window.state.cmdManager.run(command: closeTabCmd, on: window.state)
            }
            window.state.cmdManager.endGroup(forceGroup: true)

            if let lastCmd = window.state.cmdManager.lastCmd {
                windowForTabsCmd[windowCount] = lastCmd
                windowCount += 1
            }
        }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(windowForTabsCmd) else { return }
        UserDefaults.standard.set(data, forKey: BeamWindow.savedCloseTabCmdsKey)
        _ = self.data.browsingTreeSender?.groupWait()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createWindow(frame: nil)
        }

        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        CoreDataManager.shared.setup()

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

    var consoleWindow: ConsoleWindow?
    var documentsWindow: DocumentsWindow?
    var databasesWindow: DatabasesWindow?
    var tabGroupingWindow: TabGroupingWindow?

    // MARK: -
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        data.saveData()

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
            if result {
                return .terminateCancel
            }

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
                return .terminateCancel
            }
        }

        syncDataWithBeamObject { _ in
            Logger.shared.logDebug("Sending toApplicationShouldTerminate true")
            RunLoop.main.perform(inModes: [.modalPanel]) {
                Logger.shared.logDebug("Sending toApplicationShouldTerminate true (main thread)")
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }

        return .terminateLater
    }

    // MARK: -
    // MARK: Preferences
    lazy var preferences: [PreferencePane] = [
        GeneralPreferencesViewController,
        BrowserPreferencesViewController,
        CardsPreferencesViewController,
        PrivacyPreferencesViewController,
        PasswordsPreferencesViewController,
        AccountsPreferenceViewController,
        AboutPreferencesViewController,
        AdvancedPreferencesViewController,
        EditorDebugPreferencesViewController
    ]

    lazy var preferencesWindowController = PreferencesWindowController(
        preferencePanes: preferences,
        style: .toolbarItems,
        animated: true,
        hidesToolbarForSingleItem: true
    )

    @IBAction private func preferencesMenuItemActionHandler(_ sender: NSMenuItem) {
        preferencesWindowController.show()
    }

    func applicationWillHide(_ notification: Notification) {
        for window in windows {
            window.state.browserTabsManager.currentTab?.switchToBackground()
        }
    }

    func applicationDidUnhide(_ notification: Notification) {
        for window in windows where window.isMainWindow {
            window.state.browserTabsManager.currentTab?.startReading()
        }
    }

    public var isActive = false

    func applicationDidBecomeActive(_ notification: Notification) {
        isActive = true
        for window in windows where window.isMainWindow {
            window.state.browserTabsManager.currentTab?.startReading()
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
        if url.pathExtension == BeamDownloadDocument.downloadDocumentFileExtension {
            let documentURL = URL(fileURLWithPath: filename)
            if let wrapper = try? FileWrapper(url: documentURL, options: .immediate) {
                do {
                    let doc = BeamDownloadDocument()
                    doc.fileURL = documentURL
                    try doc.read(from: wrapper, ofType: "co.beamapp.download")
                    try self.data.downloadManager.downloadFile(from: doc)
                } catch {
                    Logger.shared.logError("Can't open Download Document from disk", category: .downloader)
                    return false
                }
                return true
            }
        }
        return true
    }

    // MARK: - NSAppearance
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
