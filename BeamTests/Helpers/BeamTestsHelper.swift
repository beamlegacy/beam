//
//  BeamTestsHelper.swift
//  BeamTests
//
//  Created by Jean-Louis Darmon on 09/02/2021.
//

import Foundation
import Fakery

class BeamTestsHelper {
    var sut: DocumentManager!
    lazy var coreDataManager = {
        CoreDataManager()
    }()
    lazy var mainContext = {
        coreDataManager.mainContext
    }()

    init() {
        self.coreDataManager.setup()
        self.sut = DocumentManager(coreDataManager: self.coreDataManager)
    }

    func destroyDb() {
        let semaphore = DispatchSemaphore(value: 0)

        coreDataManager.destroyPersistentStore() {
            self.coreDataManager.setup()
            semaphore.signal()
        }
        semaphore.wait()
    }

    func populateWithJournalNote(count: Int) {
        var nbrOfJournal = count
        while nbrOfJournal > 0 {
            let note = BeamNote(title: self.title())
            note.type = .journal
            note.creationDate = faker.date.backward(days: nbrOfJournal)
            note.updateDate = note.creationDate
            guard let docStruct = note.documentStruct else { return }
            self.sut.saveDocument(docStruct)
            nbrOfJournal -= 1
        }
    }

    private let faker = Faker(locale: "en-US")
    func title() -> String {
        return faker.commerce.productName() + " " + String.random(length: 10)
    }
}
