import Foundation
import Fakery

class BeamUITestsMenuGenerator {
    func executeCommand(_ command: MenuAvailableCommands) {
        switch command {
        case .populateDBWithJournal: populateWithJournalNote(count: 10)
        case .destroyDB: destroyDatabase()
        case .logout: logout()
        }
    }

    var documentManager: DocumentManager!
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    init() {
        self.coreDataManager.setup()
        self.documentManager = DocumentManager(coreDataManager: self.coreDataManager)
    }

    private func logout() {
        AccountManager.logout()
    }

    private func destroyDatabase() {
        coreDataManager.destroyPersistentStore()
        coreDataManager.setup()
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
            self.documentManager.saveDocument(docStruct, completion: nil)
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
