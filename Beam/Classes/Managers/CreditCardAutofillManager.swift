//
//  CreditCardAutofillManager.swift
//  Beam
//
//  Created by Frank Lefebvre on 20/04/2022.
//

import Foundation
import Combine
import BeamCore

final class CreditCardAutofillManager {
    static let shared = CreditCardAutofillManager()

    var changePublisher: AnyPublisher<Void, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    private var creditCardsDB: CreditCardStore? { BeamData.shared.creditCardsDB }
    private var changeSubject: PassthroughSubject<Void, Never>

    init() {
        self.changeSubject = PassthroughSubject<Void, Never>()
    }

    private func creditCardEntries(for records: [CreditCardRecord]) throws -> [CreditCardEntry] {
        try records.map { record in
            let cardNumber = try record.decryptedCardNumber()
            return CreditCardEntry(databaseID: record.uuid, cardDescription: record.cardDescription, cardNumber: cardNumber, cardHolder: record.cardHolder, expirationMonth: record.expirationMonth, expirationYear: record.expirationYear)
        }
    }

    func fetchAll(includingDisabled includeDisabled: Bool = false) -> [CreditCardEntry] {
        do {
            guard let allEntries = try creditCardsDB?.fetchAll() else { return [] }
            let filteredEntries = allEntries.filter { includeDisabled || !$0.disabled }
            return try creditCardEntries(for: filteredEntries)
        } catch CreditCardsDBError.errorFetchingCreditCards(let errorMsg) {
            Logger.shared.logError("Error while fetching all credit cards: \(errorMsg)", category: .creditCardsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .creditCardsDB)
        }
        return []
    }

    func find(cardNumber: String, includingDisabled includeDisabled: Bool = false) -> [CreditCardEntry] {
        // Can't make a database query for card number because the column is encrypted.
        fetchAll(includingDisabled: includeDisabled).filter { $0.cardNumber == cardNumber }
    }

    @discardableResult
    func save(entry: CreditCardEntry, disabled: Bool) -> CreditCardRecord? {
        guard let creditCardsDB = creditCardsDB else {
            return nil
        }

        do {
            let savedRecord: CreditCardRecord
            if let uuid = entry.databaseID, let updatedRecord = try creditCardsDB.fetchRecord(uuid: uuid) {
                savedRecord = try creditCardsDB.update(record: updatedRecord, description: entry.cardDescription, cardNumber: entry.cardNumber, holder: entry.cardHolder, expirationMonth: entry.expirationMonth, expirationYear: entry.expirationYear, disabled: disabled)
            } else {
                savedRecord = try creditCardsDB.addRecord(description: entry.cardDescription, cardNumber: entry.cardNumber, holder: entry.cardHolder, expirationMonth: entry.expirationMonth, expirationYear: entry.expirationYear, disabled: disabled)
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
        guard let creditCardsDB = creditCardsDB else {
            return
        }

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
        guard let creditCardsDB = creditCardsDB else {
            return
        }

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
        guard let creditCardsDB = creditCardsDB else {
            return
        }

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
