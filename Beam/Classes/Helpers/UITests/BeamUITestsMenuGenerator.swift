import Foundation
import Fakery
import BeamCore
import AutoUpdate

import SwiftUI // Remove once we remove .testMeetingModal menu

class BeamUITestsMenuGenerator {
    // swiftlint:disable:next cyclomatic_complexity
    func executeCommand(_ command: UITestMenuAvailableCommands) {
        switch command {
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .populatePasswordsDB: populatePasswordsDB()
        case .destroyDB: destroyDatabase()
        case .logout: logout()
        case .deleteLogs: deleteLogs()
        case .resizeWindowLandscape: resizeWindowLandscape()
        case .resizeWindowPortrait: resizeWindowPortrait()
        case .resizeSquare1000: resizeSquare1000()
        case .enableBrowsingSessionCollection: setBrowsingSessionCollection(true)
        case .disableBrowsingSessionCollection: setBrowsingSessionCollection(false)
        case .loadUITestPage1: loadUITestsPage(identifier: "1")
        case .loadUITestPage2: loadUITestsPage(identifier: "2")
        case .loadUITestPage3: loadUITestsPage(identifier: "3")
        case .loadUITestPage4: loadUITestsPage(identifier: "4")
        case .loadUITestPagePassword: loadUITestsPage(identifier: "Password")
        case .loadUITestPagePlayground: loadUITestsPage(identifier: "Playground")
        case .loadUITestPageAlerts: loadUITestsPage(identifier: "Alerts")
        case .loadUITestPageMedia: loadUITestsPage(identifier: "Media")
        case .insertTextInCurrentNote: insertTextInCurrentNote()
        case .create100Notes: Self.create100Notes()
        case .setAutoUpdateToMock: setAutoUpdateToMock()
        case .cleanDownloads: cleanDownloadFolder()
        case .omnibarFillHistory: fillHistory()
        case .signInWithTestAccount: signInWithTestAccount()
        default: break
        }
    }

    var documentManager = DocumentManager()
    var googleCalendarService = GoogleCalendarService()

    private func logout() {
        AccountManager.logout()
    }

    private func deleteLogs() {
        Logger.shared.removeFiles()
    }

    private func resizeWindowPortrait() {
        AppDelegate.main.resizeWindow(width: 800)
    }

    private func resizeWindowLandscape() {
        AppDelegate.main.resizeWindow(width: 1200)
    }

    private func resizeSquare1000() {
        AppDelegate.main.resizeWindow(width: 1000, height: 1000)
    }

    private func setBrowsingSessionCollection(_ value: Bool) {
        PreferencesManager.browsingSessionCollectionIsOn = value
    }

    private func insertTextInCurrentNote() {
        guard let currentNote = AppDelegate.main.window?.state.currentNote ?? (AppDelegate.main.window?.firstResponder as? BeamTextEdit)?.rootNode?.note else {
            Logger.shared.logDebug("Current note is nil", category: .general)

            return
        }
        Logger.shared.logDebug("Inserting text in current note", category: .documentDebug)

        guard let newNote = currentNote.deepCopy(withNewId: false, selectedElements: nil, includeFoldedChildren: false) else {
            Logger.shared.logError("Unable to create deep copy of note \(currentNote)", category: .document)
            return
        }

        for index in 0...3 {
            newNote.addChild(BeamElement("test \(index): \(BeamDate.now.description)"))
        }

        Logger.shared.logDebug("current Note: \(currentNote.id) copy: \(newNote.id)", category: .documentDebug)

        newNote.save(documentManager: documentManager) { result in
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .general)
            case .success(let success):
                Logger.shared.logInfo("Saved! \(success)", category: .documentDebug)
            }
        }
    }

    private func destroyDatabase() {
        DocumentManager().deleteAll { _ in }
        DatabaseManager().deleteAll { _ in }
        let data = AppDelegate.main.window?.state.data
        try? LinkStore.shared.deleteAll()
        try? GRDBDatabase.shared.clear()
        data?.saveData()
    }

    private func loadUITestsPage(identifier: String) {
        if let localUrl = Bundle.main.url(forResource: "UITests-\(identifier)", withExtension: "html", subdirectory: nil) {
            _ = AppDelegate.main.window?.state.createTab(withURL: localUrl, originalQuery: nil)
        }
    }

    private func populateWithJournalNote(count: Int) {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: count, journalRatio: 1, futureRatio: 0)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }

    private func populatePasswordsDB() {
        guard let url = Bundle.main.url(forResource: "UITests-Passwords", withExtension: "csv") else {
            Logger.shared.logError("Passwords.csv file not found in E2ETests/PasswordManager", category: .general)
            return
        }
        do {
            try PasswordImporter.importPasswords(fromCSV: url)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .passwordManager)
        }
    }

    private func todaysName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    static public func create100Notes() {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }

    private func setAutoUpdateToMock() {
        let appDel = AppDelegate.main
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: true)
        appDel.data.versionChecker = checker

        checker.checkForUpdates()
    }

    private func cleanDownloadFolder() {
        guard let downloadUrl = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl else { return }
        let fileManager = FileManager.default
        guard let content = try? fileManager.contentsOfDirectory(atPath: downloadUrl.path) else { return }

        let elementToDelete = content.filter { $0.hasSuffix("SF-Symbols-3.dmg") || $0.hasSuffix("SF-Symbols-3.dmg.beamdownload") }
        elementToDelete.forEach { try? fileManager.removeItem(at: downloadUrl.appendingPathComponent($0)) }
    }

    private func fillHistory(longTitle: Bool = false) {
        addPageToHistory(url: "https://fr.wikipedia.org/wiki/Hello_world", title: "Hello world", id: UUID())
        addPageToHistory(url: "https://en.wikipedia.org/wiki/Hubert_Blaine_Wolfeschlegelsteinhausenbergerdorff_Sr.",
                         title: "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.", id: UUID())
        addPageToHistory(url: "https://www.google.com/search?q=Beam%20the%20best%20browser&client=safari", title: "Beam the best browser", id: UUID())
    }

    private func addPageToHistory(url: String, title: String, id: UUID) {
        _ = IndexDocument(source: url, title: title, contents: title)
        try? GRDBDatabase.shared.insertHistoryUrl(urlId: id, url: url, title: title, content: title)
        var frecency = FrecencyUrlRecord(urlId: id, lastAccessAt: BeamDate.now, frecencyScore: 1, frecencySortScore: 1, frecencyKey: AutocompleteManager.urlFrecencyParamKey)
        try? GRDBDatabase.shared.saveFrecencyUrl(&frecency)
    }

    private func signInWithTestAccount() {
        guard !AuthenticationManager.shared.isAuthenticated else { return }

        let accountManager = AccountManager()
        let email = Configuration.testAccountEmail
        let password = Configuration.testAccountPassword

        accountManager.signIn(email, password) { result in
            if case .failure(let error) = result {
                fatalError(error.localizedDescription)
            }
        }
    }
}
