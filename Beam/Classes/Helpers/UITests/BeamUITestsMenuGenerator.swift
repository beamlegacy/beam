import Foundation
import Fakery
import BeamCore

class BeamUITestsMenuGenerator {
    // swiftlint:disable:next cyclomatic_complexity
    func executeCommand(_ command: MenuAvailableCommands) {
        switch command {
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .destroyDB: destroyDatabase()
        case .logout: logout()
        case .deleteLogs: deleteLogs()
        case .resizeWindowLandscape: resizeWindowLandscape()
        case .resizeWindowPortrait: resizeWindowPortrait()
        case .loadUITestPage1: loadUITestsPage(page: 1)
        case .loadUITestPage2: loadUITestsPage(page: 2)
        case .loadUITestPage3: loadUITestsPage(page: 3)
        case .loadUITestPage4: loadUITestsPage(page: 4)
        case .loadUITestPage5: loadUITestsPage(page: 5)
        case .loadUITestPage6: loadUITestsPage(page: 6)
        case .insertTextInCurrentNote: insertTextInCurrentNote()
        case .create100Notes: create100Notes()
        default: break
        }
    }

    var documentManager = DocumentManager()

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

    private func insertTextInCurrentNote() {
        guard let currentNote = AppDelegate.main.window?.state.currentNote ?? (AppDelegate.main.window?.firstResponder as? BeamTextEdit)?.rootNode.note else {
            Logger.shared.logDebug("Current note is nil", category: .general)

            return
        }
        Logger.shared.logDebug("Inserting text in current note", category: .documentDebug)

        guard let newNote = currentNote.deepCopy(withNewId: false, selectedElements: nil) else {
            Logger.shared.logError("Unable to create deep copy of note \(currentNote)", category: .document)
            return
        }

        for index in 0...3 {
            newNote.addChild(BeamElement("test \(index): \(Date().description)"))
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
        data?.linkManager.deleteAllLinks()
        try? GRDBDatabase.shared.clear()
        data?.saveData()
    }

    private func loadUITestsPage(page: Int) {
        if let localUrl = Bundle.main.url(forResource: "UITests-\(page)", withExtension: "html", subdirectory: nil) {
            _ = AppDelegate.main.window?.state.createTab(withURL: localUrl, originalQuery: nil)
        }
    }

    private func populateWithJournalNote(count: Int) {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: count, journalRatio: 1, futureRatio: -1)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }

    private func todaysName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func create100Notes() {
        let documentManager = DocumentManager()
        let generator = FakeNoteGenerator(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        generator.generateNotes()
        for note in generator.notes {
            note.save(documentManager: documentManager)
        }
    }
}
