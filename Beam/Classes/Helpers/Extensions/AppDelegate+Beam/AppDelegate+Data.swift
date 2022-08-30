import Foundation
import Cocoa
import BeamCore

extension AppDelegate {
    @IBAction func deleteLocalContent(_ sender: Any) {
        deleteAllLocalData()
    }

    func deleteAllLocalData() {
        // Clustering Orphaned file
        do {
            try data.currentAccount?.data.clusteringOrphanedUrlManager.clear()
        } catch {
            Logger.shared.logError("Could not delete Clustering Orphaned file", category: .general)
        }
        // TopDomain
        do {
            try TopDomainDatabase.shared.clear()
        } catch {
            Logger.shared.logError("Could not delete TopDomains", category: .general)
        }

        // CoreData Logger
        LoggerRecorder.shared.deleteAll(nil)

        // UserDefaults
        BeamUserDefaultsManager.clear()
        StandardStorable<Any>.clear()

        // Favicon Cache
        FaviconProvider.shared.clear()

        // Cookies && Cache
        data.currentAccount?.data.clearCookiesAndCache()

        // BeamFile
        BeamFileDBManager.shared?.deleteAll(includedRemote: false) { _ in }
        // Link Store
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
        //Contacts
        data.currentAccount?.data.contactsManager.deleteAll(includedRemote: false) { _ in }
        // Passwords
        data.currentAccount?.data.passwordManager.deleteAll(includedRemote: false) { _ in }
        // Note Frecency
        if let objectManager = data.currentAccount?.data.objectManager {
            GRDBNoteFrecencyStorage(objectManager: objectManager).deleteAll(includedRemote: false) { _ in }
        }
        // BeamObject Coredata Checksum
        do {
            try BeamObjectChecksum.deleteAll()
        } catch {
            Logger.shared.logError("Could not delete BeamObjectChecksum", category: .general)
        }

        // Notes and Databases
        self.deleteDocumentsAndDatabases(includedRemote: false)

        // GRDB
        do {
            try data.clearAllAccountsAndSetupDefaultAccount()
        } catch {
            Logger.shared.logError("Could not delete GRDB Databases", category: .general)
        }
    }

    @IBAction func resetDatabase(_ sender: Any) {
        deleteDocumentsAndDatabases(includedRemote: true)
    }

    func deleteDocumentsAndDatabases(includedRemote: Bool) {
        // Documents and Databases
        BeamNote.clearFetchedNotes()
        guard let account = data.currentAccount else {
            return
        }

        for db in account.allDatabases {
            db.clear()
        }

        AppDelegate.main.closePreferencesWindow()
        AppDelegate.main.windows.forEach { window in
            window.close()
        }
        AppDelegate.main.windows = []
        self.deleteSessionData()
        account.data.deleteJournal()
        account.data.onboardingManager.forceDisplayOnboarding()
        account.data.onboardingManager.delegate = self
        account.data.onboardingManager.presentOnboardingWindow()
    }

    @IBAction func exportNotes(_ sender: Any) {
        // the panel is automatically displayed in the user's language if your project is localized
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = false

        // this is a preferred method to get the desktop URL
        savePanel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!

        // TODO: i18n
        savePanel.title = "Export all notes"
        savePanel.message = "Choose the file to export all notes."
        savePanel.showsHiddenFiles = false
        savePanel.showsTagField = false
        savePanel.canCreateDirectories = true
        savePanel.allowsOtherFileTypes = false
        savePanel.isExtensionHidden = true
        savePanel.nameFieldStringValue = BeamNoteCollectionWrapper.preferredFilename

        if savePanel.runModal() == .OK, let url = savePanel.url {
            if !url.startAccessingSecurityScopedResource() {
                // TODO: raise error?
                Logger.shared.logError("startAccessingSecurityScopedResource returned false. This directory might not need it, or this URL might not be a security scoped URL, or maybe something's wrong?", category: .general)
            }

            do {
//                try CoreDataManager.shared.backup(url)
                let collection = BeamNoteCollectionWrapper()
                try collection.write(to: url, ofType: BeamNoteCollectionWrapper.documentTypeName)
            } catch {
                UserAlert.showError(message: "Could not export backup note collection: \(error.localizedDescription)",
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
        openPanel.allowedFileTypes = ["beamCollection"]

        // TODO: i18n
        openPanel.title = "Select the note collection"
        openPanel.message = "Beam will import this backup, existing notes will be updated or renamed with the content on disk."

        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let url = openPanel?.url else { openPanel?.close(); return }

            do {
                let noteCollection = try BeamNoteCollectionWrapper(fileWrapper: FileWrapper(url: url, options: .immediate))
                try noteCollection.importNotes()
            } catch {
                UserAlert.showError(message: "Could not import collection",
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
            guard result == .OK, let selectedPath = openPanel?.url?.path,
                  let database = BeamData.shared.currentDatabase
            else { openPanel?.close(); return }

            let beforeNotesCount = database.documentsCount()

            let roamImporter = RoamImporter()
            do {
                try roamImporter.parseAndCreate(CoreDataManager.shared.mainContext, selectedPath)
            } catch {
                // TODO: raise error?
                Logger.shared.logError("error: \(error.localizedDescription)", category: .general)
            }
            let afterNotesCount = database.documentsCount()

            UserAlert.showMessage(message: "Roam file has been imported",
                                  informativeText: "\(afterNotesCount - beforeNotesCount) notes have been imported")

            openPanel?.close()
        }
    }

    // MARK: Markdown

    @IBAction func importMarkdown(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [BeamUniformTypeIdentifiers.plainTextType]
        // TODO: i18n
        openPanel.title = loc("Choose your Markdown file")
        openPanel.begin { [weak openPanel] result in
            guard result == .OK, let selectedURLs = openPanel?.urls else { return }

            let importer = MarkdownImporter()

            var failedImports: UInt = .zero

            for url in selectedURLs {
                do {
                    try importer.import(contents: url)
                } catch {
                    Logger.shared.logError("Error importing to Markdown: \(error)", category: .general)
                    failedImports += 1
                }
            }

            if failedImports != .zero {
                let errorMessage = loc("Failed to import \(failedImports) \(failedImports > 1 ? "notes" : "note").")
                UserAlert.showError(message: errorMessage)
            }
        }
    }

    @IBAction func exportToMarkdown(_ sender: Any) {
        exportNotesToMarkdown([])
    }
}

// MARK: - DB Integrity check
extension AppDelegate {
    private static var lastLinkDBIntegrityCheckKey: String { "LinkStoreLastIntegrityCheck" }
    @UserDefault(key: lastLinkDBIntegrityCheckKey, defaultValue: nil)
    private static var lastLinkDBIntegrityCheck: Date?

    /// We discovered in https://linear.app/beamapp/issue/BE-4107/
    /// That the linkContent FTS table can have some integrity issues, producing incoherent search result.
    /// We're not sure yet what was the cause, so we're adding a safe guard  checking and repairing any integrity issue found every day.
    /// And we send a Sentry report if needed.
    public func checkAndRepairLinkDBIfNeeded() {
        guard Self.lastLinkDBIntegrityCheck == nil || Self.lastLinkDBIntegrityCheck?.timeIntervalSinceNow ?? 0 < -86400 else { return }
        Self.lastLinkDBIntegrityCheck = BeamDate.now
        data.checkAndRepairDB()
    }
}
