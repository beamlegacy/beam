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

    let documentManager = DocumentManager()
    let databaseManager = DatabaseManager()
    let beamObjectManager = BeamObjectManager()

    #if DEBUG
    var beamUIMenuGenerator: BeamUITestsMenuGenerator!
    #endif

    func resizeWindow(width: CGFloat) {
        var windowRect = window?.frame ?? NSRect(origin: .zero, size: CGSize(width: width, height: 600))
        windowRect.size.width = width
        window?.setFrame(windowRect, display: true)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        CoreDataManager.shared.setup()
        LibrariesManager.shared.configure()
        ContentBlockingManager.shared.setup()
        PasswordGenerator.shared.setup()
        BeamObjectManager.setup()

        data = BeamData()

        for arg in ProcessInfo.processInfo.arguments {
            switch arg {
            case "--export-all-browsing-sessions":
                export_all_browsing_sessions()
                exit(0)
            default:
                break
            }
        }

        updateBadge()
        createWindow(frame: nil, reloadState: Configuration.stateRestorationEnabled)

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logInfo("🛑 API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }

        #if DEBUG
        self.beamUIMenuGenerator = BeamUITestsMenuGenerator()
        prepareMenuForTestEnv()
        NSApp.windowsMenu?.addItem(NSMenuItem(title: "Show TabGrouping",
                                              action: #selector(showTabGroupingWindow(_:)),
                                              keyEquivalent: ""))
        #endif

        syncData()
        fetchTopDomains()
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

    func syncData() {
        guard Configuration.env != "test" else { return }
        guard AuthenticationManager.shared.isAuthenticated else { return }

        // With Vinyl and Network test recording, and this executing, it generates async network
        // calls and randomly fails.

        // My feeling is we should sync + trigger notification and only start network calls when
        // this sync has finished.

        if Configuration.beamObjectAPIEnabled {
            do {
                Logger.shared.logInfo("syncAllFromAPI calling", category: .beamObjectNetwork)
                try beamObjectManager.syncAllFromAPI { _ in
                    Logger.shared.logInfo("syncAllFromAPI called", category: .beamObjectNetwork)
                }
            } catch {
                Logger.shared.logError("Couldn't sync beam objects: \(error.localizedDescription)",
                                       category: .document)
            }
        } else {
            databaseManager.syncAll { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError("Couldn't sync databases: \(error.localizedDescription)",
                                           category: .database)
                case .success(let success):
                    guard success == true else {
                        Logger.shared.logError("Couldn't sync databases but no error",
                                               category: .database)
                        return
                    }

                    self.documentManager.syncAll { result in
                        switch result {
                        case .failure(let error):
                            Logger.shared.logError("Couldn't sync documents: \(error.localizedDescription)",
                                                   category: .document)
                        case .success(let success):
                            if !success {
                                Logger.shared.logError("Couldn't sync documents but no error",
                                                       category: .document)
                            }
                        }
                    }
                }
            }
        }
    }

    func updateBadge() {
        let count = Document.countWithPredicate(CoreDataManager.shared.mainContext)
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : ""
    }

    @discardableResult
    func createWindow(frame: NSRect?, reloadState: Bool) -> BeamWindow {
        // Create the window and set the content view.
        let window = BeamWindow(contentRect: frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
                            data: data,
                            reloadState: reloadState)
        if frame == nil {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        subscribeToStateChanges(for: window.state)
        return window
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        for window in windows {
            for tab in window.state.browserTabsManager.tabs {
                tab.closeApp()
            }
        }
        if let beamWindow = windows.first {
            beamWindow.saveDefaults()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createWindow(frame: nil, reloadState: Configuration.stateRestorationEnabled)
        }

        return true
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return CoreDataManager.shared.mainContext.undoManager
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
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
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }

        if !context.hasChanges {
            return .terminateNow
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
        // If we got here, it is time to quit.
        return .terminateNow
    }

    @IBAction func newDocument(_ sender: Any?) {
        createWindow(frame: nil, reloadState: false)
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
        AdvancedPreferencesViewController
    ]

    lazy var preferencesWindowController = PreferencesWindowController(
        preferencePanes: preferences,
        style: .toolbarItems,
        animated: false,
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

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in windows where window.isMainWindow {
            window.state.browserTabsManager.currentTab?.startReading()
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
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
}
