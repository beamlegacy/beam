//
//  CreditCardAutofillManager.swift
//  Beam
//
//  Created by Frank Lefebvre on 20/04/2022.
//

import Foundation
import Combine
import BeamCore

class CreditCardAutofillManager {
    static let shared = CreditCardAutofillManager()
    static private var creditCardsDBPath: String { BeamData.dataFolder(fileName: "credit_cards.db") }

    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private var creditCardsDB: CreditCardStore
    private var changeSubject: PassthroughSubject<Void, Never>

    convenience init() {
        do {
            let creditCardsDB = try CreditCardsDB(path: Self.creditCardsDBPath)
            self.init(creditCardsDB: creditCardsDB)
        } catch {
            fatalError("Error while creating the Credit Cards Database \(error)")
        }
    }

    init(creditCardsDB: CreditCardStore) {
        self.creditCardsDB = creditCardsDB
        self.changeSubject = PassthroughSubject<Void, Never>()
    }

    private func creditCardEntries(for records: [CreditCardRecord]) throws -> [CreditCardEntry] {
        try records.map { record in
            let cardNumber = try record.decryptedCardNumber()
            return CreditCardEntry(databaseID: record.uuid, cardDescription: record.cardDescription, cardNumber: cardNumber, cardHolder: record.cardHolder, expirationMonth: record.expirationMonth, expirationYear: record.expirationYear)
        }
    }

    func fetchAll() -> [CreditCardEntry] {
        do {
            let allEntries = try creditCardsDB.fetchAll()
            return try creditCardEntries(for: allEntries)
        } catch CreditCardsDBError.errorFetchingCreditCards(let errorMsg) {
            Logger.shared.logError("Error while fetching all credit cards: \(errorMsg)", category: .creditCardsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
        return []
    }

    @discardableResult
    func save(entry: CreditCardEntry) -> CreditCardRecord? {
        do {
            let savedRecord: CreditCardRecord
            if let uuid = entry.databaseID, let updatedRecord = try creditCardsDB.fetchRecord(uuid: uuid) {
                savedRecord = try creditCardsDB.update(record: updatedRecord, description: entry.cardDescription, cardNumber: entry.cardNumber, holder: entry.cardHolder, expirationMonth: entry.expirationMonth, expirationYear: entry.expirationYear)
            } else {
                savedRecord = try creditCardsDB.addRecord(description: entry.cardDescription, cardNumber: entry.cardNumber, holder: entry.cardHolder, expirationMonth: entry.expirationMonth, expirationYear: entry.expirationYear)
            }
            changeSubject.send()
            return savedRecord
        } catch CreditCardsDBError.cantSave(let errorMsg) {
            Logger.shared.logError("Error while saving credit card \(entry.cardDescription): \(errorMsg)", category: .creditCardsDB)
        } catch CreditCardsDBError.cantEncryptCardNumber {
            Logger.shared.logError("Error while encrypting card number for \(entry.cardDescription)", category: .encryption)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
        return nil
    }

    func markDeleted(entry: CreditCardEntry) {
        do {
            guard let uuid = entry.databaseID, let deletedRecord = try creditCardsDB.fetchRecord(uuid: uuid) else {
                Logger.shared.logError("Credit card to be deleted cannot be found: \(entry.cardDescription)", category: .creditCardsDB)
                return
            }
            try creditCardsDB.markDeleted(record: deletedRecord)
            changeSubject.send()
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
    }

    func markAllDeleted() {
        do {
            _ = try creditCardsDB.markAllDeleted()
            changeSubject.send()
        } catch CreditCardsDBError.cantDelete(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all credit cards: \(errorMsg)", category: .creditCardsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
    }

    func deleteAll(includedRemote: Bool) {
        do {
            try creditCardsDB.deleteAll()
            changeSubject.send()
        } catch CreditCardsDBError.cantDelete(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all passwords: \(errorMsg)", category: .creditCardsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
    }

    func count() -> Int {
        fetchAll().count
    }
}
