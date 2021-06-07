import Foundation
import Fakery
import BeamCore

class BeamUITestsMenuGenerator {
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

    private func destroyDatabase() {
        DocumentManager().deleteAll { _ in }
        DatabaseManager().deleteAll { _ in }
        try? AppDelegate.main.data.indexer.clear()
    }

    private func loadUITestsPage(page: Int) {
        if let localUrl = Bundle.main.url(forResource: "NavigationCollectUITests-\(page)", withExtension: "html", subdirectory: nil) {
            _ = AppDelegate.main.window.state.createTab(withURL: localUrl, originalQuery: nil)
        }
    }

    let faker = Faker(locale: "en-US")
    private func populateWithJournalNote(count: Int) {
        var nbrOfJournal = count
        while nbrOfJournal > 0 {
            let date = faker.date.backward(days: nbrOfJournal)
            let title = todaysName(date)
            let note = BeamNote(title: title)
            note.type = .journal
            note.creationDate = date
            note.updateDate = date
            guard let docStruct = note.documentStruct else { return }
            _ = self.documentManager.save(docStruct, completion: nil)
            nbrOfJournal -= 1
        }
    }

    private func todaysName(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.doesRelativeDateFormatting = false
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }
}
