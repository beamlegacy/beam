import Foundation
import Cocoa
import BeamCore

extension AppDelegate {
    @IBAction func deleteLocalDocuments(_ sender: Any) {
        deleteDocumentsAndDatabases(includedRemote: false)
    }

    @IBAction func resetDatabase(_ sender: Any) {
        deleteDocumentsAndDatabases(includedRemote: true)
    }

    private func deleteDocumentsAndDatabases(includedRemote: Bool) {
        documentManager.deleteAll(includedRemote: includedRemote) { result in
            switch result {
            case .failure(let error):
                UserAlert.showError(message: "Could not delete documents",
                                    error: error)
            case .success:
                self.databaseManager.deleteAll(includedRemote: includedRemote) { result in
                    switch result {
                    case .failure(let error):
                        // TODO: i18n
                        UserAlert.showError(message: "Could not delete databases",
                                            error: error)
                    case .success:
                        UserAlert.showMessage(message: "All documents and databases deleted. Beam must exit now.",
                                              buttonTitle: "Exit now")
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }

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
        let dateString = dateFormatter.string(from: BeamDate.now)
        savePanel.nameFieldStringValue = "BeamExport-\(dateString).sqlite"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            if !url.startAccessingSecurityScopedResource() {
                // TODO: raise error?
                Logger.shared.logError("startAccessingSecurityScopedResource returned false. This directory might not need it, or this URL might not be a security scoped URL, or maybe something's wrong?", category: .general)
            }

            do {
                try CoreDataManager.shared.backup(url)
            } catch {
                UserAlert.showError(message: "Could not import backup: \(error.localizedDescription)",
                                    error: error)
            }
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

            do {
                try CoreDataManager.shared.importBackup(url)

                let documentsCount = Document.countWithPredicate(CoreDataManager.shared.mainContext)

                // TODO: i18n
                UserAlert.showError(message: "Backup file has been imported",
                                    informativeText: "\(documentsCount) notes have been imported")
            } catch {
                UserAlert.showError(message: "Could not import backup",
                                    error: error)
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

            let beforeNotesCount = Document.countWithPredicate(CoreDataManager.shared.mainContext)

            let roamImporter = RoamImporter()
            do {
                try roamImporter.parseAndCreate(CoreDataManager.shared.mainContext, selectedPath)
                try CoreDataManager.shared.save()
            } catch {
                // TODO: raise error?
                Logger.shared.logError("error: \(error.localizedDescription)", category: .general)
            }
            let afterNotesCount = Document.countWithPredicate(CoreDataManager.shared.mainContext)

            UserAlert.showMessage(message: "Roam file has been imported",
                                  informativeText: "\(afterNotesCount - beforeNotesCount) notes have been imported")

            openPanel?.close()
        }
    }
}
