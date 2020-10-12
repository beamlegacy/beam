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

    @IBOutlet var window: BeamWindow!
    var windows: [BeamWindow] = []
    var data: BeamData = BeamData()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.mainMenu?.item(withTitle: "Window")?.submenu?.delegate = self
        NSApp.mainMenu?.item(withTitle: "Window")?.submenu?.delegate = self

        CoreDataManager.shared.setup()

        createWindow()
    }

    func createWindow() {
        // Create the window and set the content view.
        window = BeamWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), cloudKitContainer: CoreDataManager.shared.persistentContainer, data: data)
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
        if menu.title == "Window" {
            toggleVisibility(false, ofAlternatesKeyEquivalentsItems: menu.items)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu.title == "Window" {
            toggleVisibility(true, ofAlternatesKeyEquivalentsItems: menu.items)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: - Core Data Saving and Undo support

    @IBAction func resetDatabase(_ sender: Any) {
        CoreDataManager.shared.destroyPersistentStore {
            CoreDataManager.shared.setup()

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Database deleted"
            alert.informativeText = "All coredata has been deleted"
            alert.runModal()
        }
    }

    @IBAction func importRoam(_ sender: Any) {
        print("importing roam")

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
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
                // TODO: show error
                fatalError("Aie")
            }

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

}
