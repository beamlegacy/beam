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
#if canImport(Sparkle)
import Sparkle
#endif
import Preferences

@objc(BeamApplication)
public class BeamApplication: SentryCrashExceptionApplication {
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // swiftlint:disable:next force_cast
    class var main: AppDelegate { NSApplication.shared.delegate as! AppDelegate }

    @IBOutlet var window: BeamWindow!
    var windows: [BeamWindow] = []
    var data: BeamData!

    let documentManager = DocumentManager()
    #if DEBUG
    var beamHelper: BeamTestsHelper?
    #endif

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if DEBUG
        if Configuration.env != "release" {
            self.beamHelper = BeamTestsHelper()
            prepareMenuForTestEnv()
        }
        #endif
        for item in NSApp.mainMenu?.items ?? [] {
            item.submenu?.delegate = self

            prepareMenu(items: item.submenu?.items ?? [], for: Mode.today.rawValue)

        }
        CoreDataManager.shared.setup()
        LibrariesManager.shared.configure()

        #if canImport(Sparkle)
        if Configuration.sparkleUpdate {
            let sparkleUpdater = SPUUpdater(hostBundle: Bundle.main,
                                            applicationBundle: Bundle.main,
                                            userDriver: SPUStandardUserDriver(),
                                            delegate: nil)
            sparkleUpdater.checkForUpdatesInBackground()
        }
        #endif

        data = BeamData()
        updateBadge()
        createWindow()

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logInfo("🛑 API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }
    }

    func updateBadge() {
        let count = Document.countWithPredicate(CoreDataManager.shared.mainContext)
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : ""
    }

    func createWindow() {
        // Create the window and set the content view.
        window = BeamWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), data: data)
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    func toggleVisibility(_ visible: Bool, ofAlternatesKeyEquivalentsItems items: [NSMenuItem]) {
        for item in items.filter({ $0.tag < 0 }) {
            item.isHidden = !visible
        }
    }

    func prepareMenu(items: [NSMenuItem], for mode: Int) {
        for item in items {
            if item.tag == 0 { continue }

            let value = abs(item.tag)
            let mask = value & mode

            item.isEnabled = mask != 0
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // menu items with tag == 0 are ALWAYS enabled and visible
        // menu items with tag == mode are only enabled in the corresponding mode
        // menu items with tag == -mode are only enabled and visible in the corresponding mode

        toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
        prepareMenu(items: menu.items, for: window.state.mode.rawValue)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        data.saveData()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createWindow()
        }

        return true
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return CoreDataManager.shared.mainContext.undoManager
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager
            .shared()
            .setEventHandler(
                self,
                andSelector: #selector(handleURL(event:reply:)),
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
            let incomingURL = userActivity.webpageURL,
            let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        return parseHTTPScheme(components: components)
    }

    var consoleWindow: ConsoleWindow?
    var documentsWindow: DocumentsWindow?

    // MARK: -
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
        createWindow()
    }

    // MARK: -
    // MARK: Preferences
    lazy var preferences: [PreferencePane] = [
        AccountsPreferenceViewController(),
        AdvancedPreferencesViewController()
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
            window.state.currentTab?.switchToBackground()
        }
    }

    func applicationDidUnhide(_ notification: Notification) {
        for window in windows where window.isMainWindow {
            window.state.currentTab?.startReading()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in windows where window.isMainWindow {
            window.state.currentTab?.startReading()
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        for window in windows {
            window.state.currentTab?.switchToBackground()
        }
    }

    @IBAction func goBack(_ sender: Any?) {
        window.state.goBack()
    }

    @IBAction func goForward(_ sender: Any?) {
        window.state.goForward()
    }

    @IBAction func toggleBetweenWebAndNote(_ sender: Any) {
        window.state.toggleBetweenWebAndNote()
    }
}
