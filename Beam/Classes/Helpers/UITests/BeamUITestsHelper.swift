import Foundation
import Fakery

class BeamUITestsHelper {
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

    func destroyDatabase() {
        coreDataManager.destroyPersistentStore()
        coreDataManager.setup()
    }

    func populateWithJournalNote(count: Int) {
        var nbrOfJournal = count
        while nbrOfJournal > 0 {
            let note = BeamNote(title: self.title())
            note.type = .journal
            note.creationDate = faker.date.backward(days: nbrOfJournal)
            note.updateDate = note.creationDate
            guard let docStruct = note.documentStruct else { return }
            self.documentManager.saveDocument(docStruct, completion: nil)
            nbrOfJournal -= 1
        }
    }

    private let faker = Faker(locale: "en-US")
    func title() -> String {
        return faker.commerce.productName() + " " + String.random(length: 10)
    }
}
