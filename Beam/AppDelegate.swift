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
import Sparkle

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
    var data: BeamData = BeamData()

    let documentManager = DocumentManager()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.mainMenu?.item(withTitle: "File")?.submenu?.delegate = self
        NSApp.mainMenu?.item(withTitle: "Window")?.submenu?.delegate = self

        CoreDataManager.shared.setup()
        LibrariesManager.shared.configure()

        #if !DEBUG
        let sparkleUpdater = SPUUpdater(hostBundle: Bundle.main,
                                        applicationBundle: Bundle.main,
                                        userDriver: SPUStandardUserDriver(),
                                        delegate: nil)

        sparkleUpdater.checkForUpdatesInBackground()
        #endif

        updateBadge()
        createWindow()

        // So we remember we're not currently using the default api server
        if Configuration.apiHostnameDefault != Configuration.apiHostname {
            Logger.shared.logInfo("🛑 API HOSTNAME is \(Configuration.apiHostname)", category: .general)
        }
    }

    func updateBadge() {
        let count = Note.countWithPredicate(CoreDataManager.shared.mainContext)
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
        for item in items.filter({ $0.tag == 2 }) {
            item.isHidden = !visible
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    private let accountManager = AccountManager()
    var accountWindow: AccountWindow?
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

    var notesWindow: NotesWindow?
    var noteWindows: [NoteWindow] = []
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
}
