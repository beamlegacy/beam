//
//  AppDelegate.swift
//  Beam
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Cocoa
import SwiftUI
import Combine

@objc(BeamApplication)
public class BeamApplication: NSApplication {

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    class var main: AppDelegate { NSApplication.shared.delegate as! AppDelegate }

    @IBOutlet var window: BeamWindow!
    var windows: [BeamWindow] = []
    var data: BeamData = BeamData()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerFonts()
        NSApp.mainMenu?.item(withTitle: "File")?.submenu?.delegate = self
        NSApp.mainMenu?.item(withTitle: "Window")?.submenu?.delegate = self

        CoreDataManager.shared.setup()

        updateBadge()
        createWindow()
    }

    private func updateBadge() {
        let count = Note.countWithPredicate(CoreDataManager.shared.mainContext)
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : ""
    }

    func registerFonts() {
        registerFont(fontName: "SFSymbolsFallback.ttf")
    }

    func registerFont(fontName: String) {
        let availableFonts = NSFontManager.shared.availableFonts

        guard availableFonts.contains(fontName) else { return }
        let bundle = Bundle.main
        guard let resourcePath = bundle.resourcePath else {
            print("unable to find resourcePath")
            return }
        let fontURL = URL(fileURLWithPath: resourcePath + "/" + fontName)
        print("Font URL \(fontURL)")
        if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) {
            print("unable to register font \(fontName)")
        }
    }

    func createWindow() {
        // Create the window and set the content view.
        window = BeamWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 895), data: data)
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createWindow()
        }

        return false
    }

    // MARK: - Core Data Saving and Undo support

    @IBAction func resetDatabase(_ sender: Any) {
        CoreDataManager.shared.destroyPersistentStore {
            CoreDataManager.shared.setup()
            self.updateBadge()

            let alert = NSAlert()
            alert.alertStyle = .critical
            // TODO: i18n
            alert.messageText = "Database deleted"
            alert.informativeText = "All coredata has been deleted"
            alert.runModal()

        }
    }

    // MARK: - Notes export
    @IBAction func exportNotes(_ sender: Any) {
        // the panel is automatically displayed in the user's language if your project is localized
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = false

        // this is a preferred method to get the desktop URL
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!

        // TODO: i18n
        savePanel.title = "Export all notes"
        savePanel.message = "Choose the file to export all notes, please note this is used for development mode only."
        savePanel.showsHiddenFiles = false
        savePanel.showsTagField = false
        savePanel.canCreateDirectories = true
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = true

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let dateString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "BeamExport-\(dateString).sqlite"

        if savePanel.runModal() == NSApplication.ModalResponse.OK, let url = savePanel.url {
            if !url.startAccessingSecurityScopedResource() {
                // TODO: raise error?
                print("startAccessingSecurityScopedResource returned false. This directory might not need it, or this URL might not be a security scoped URL, or maybe something's wrong?")
            }

            CoreDataManager.shared.backup(url)

            url.stopAccessingSecurityScopedResource()
        }
    }

    @IBAction func importNotes(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["sqlite"]

        // TODO: i18n
        openPanel.title = "Select the backup sqlite file"
        openPanel.message = "We will delete all notes and import this backup"

        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let url = openPanel?.url else { openPanel?.close(); return }

            CoreDataManager.shared.importBackup(url) {
                CoreDataManager.shared.setup()
                self.updateBadge()

                let alert = NSAlert()
                alert.alertStyle = .critical

                let notesCount = Note.countWithPredicate(CoreDataManager.shared.mainContext)
                let bulletsCount = Bullet.countWithPredicate(CoreDataManager.shared.mainContext)

                // TODO: i18n
                alert.messageText = "Backup file has been imported"
                alert.informativeText = "\(notesCount) notes and \(bulletsCount) bullets have been imported"
                alert.runModal()
            }

            openPanel?.close()
        }
    }

    // MARK: - Roam import
    @IBAction func importRoam(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        // TODO: i18n
        openPanel.title = "Choose your ROAM JSON Export"
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedPath = openPanel?.url?.path else { openPanel?.close(); return }

            let beforeNotesCount = Note.countWithPredicate(CoreDataManager.shared.mainContext)
            let beforeBulletsCount = Bullet.countWithPredicate(CoreDataManager.shared.mainContext)

            let roamImporter = RoamImporter()
            do {
                try roamImporter.parseAndCreate(CoreDataManager.shared.mainContext, selectedPath)
                CoreDataManager.shared.save()
            } catch {
                // TODO: raise error?
                fatalError("Aie")
            }
            self.updateBadge()

            let afterNotesCount = Note.countWithPredicate(CoreDataManager.shared.mainContext)
            let afterBulletsCount = Bullet.countWithPredicate(CoreDataManager.shared.mainContext)

            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Roam file has been imported"
            alert.informativeText = "\(afterNotesCount - beforeNotesCount) notes and \(afterBulletsCount - beforeBulletsCount) bullets have been imported"
            alert.runModal()

            openPanel?.close()
        }
    }

    @IBAction func saveAction(_ sender: AnyObject?) {
        CoreDataManager.shared.save()
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return CoreDataManager.shared.mainContext.undoManager
    }

    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        print(userActivity)

        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL,
            let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        return parseBeamURL(components: components)
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

    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: path) else {

            print("Could not parse \(String(describing: event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue)) \(reply)")
            return
        }

        // Process the URL.
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Invalid URL or path missing")
            return
        }

        parseBeamURL(components: components)
    }

    @discardableResult
    private func parseBeamURL(components: NSURLComponents) -> Bool {
        // Process the URL.
        guard let urlPath = components.path else {
            print("Invalid URL or path missing")
            return false
        }

        guard components.host == Config.hostname else { return false }

        switch urlPath.dropFirst() {
        case "note":
            if let params = components.queryItems {
                if let noteId = params.first(where: { $0.name == "id" })?.value {
                    showNoteID(id: noteId)
                    return true
                } else if let noteTitle = params.first(where: { $0.name == "title" })?.value {
                    showNoteTitle(title: noteTitle)
                    return true
                }
            }
        case "bullet":
            if let params = components.queryItems,
               let bulletId = params.first(where: { $0.name == "id" })?.value {
                showBullet(id: bulletId)
                return true
            }
        default: break
        }

        print("Didn't detect link \(components)")

        return false
    }

    // MARK: - Note Windows
    var notesWindow: NotesWindow?
    @IBAction func showAllNotes(_ sender: Any) {
        notesWindow = notesWindow ?? NotesWindow(
            contentRect: window.frame)
        notesWindow?.title = "All Notes"
        notesWindow?.center()
        notesWindow?.makeKeyAndOrderFront(window)
    }

    var noteWindows: [NoteWindow] = []

    private func showNote(_ note: Note) {
        let noteWindow = NoteWindow(note: note, contentRect: window.frame)
        noteWindow.center()
        noteWindow.makeKeyAndOrderFront(window)
    }

    private func showNoteID(id: String) {
        guard let uuid = UUID(uuidString: id),
              let note = Note.fetchWithId(CoreDataManager.shared.mainContext, uuid) else { return }

        showNote(note)
    }

    private func showNoteTitle(title: String) {
        guard let note = Note.fetchWithTitle(CoreDataManager.shared.mainContext, title) else { return }

        showNote(note)
    }

    private func showBullet(id: String) {
        guard let uuid = UUID(uuidString: id),
              let bullet = Bullet.fetchWithId(CoreDataManager.shared.mainContext, uuid),
              let note = bullet.note else { return }

        showNote(note)
    }

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
