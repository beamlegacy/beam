//
//  MockAutocompleteStores.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//
import BeamCore
@testable import Beam

class MockCreditCardStore: CreditCardStore {

    enum Error: Swift.Error {
        case notFound
    }

    static let shared = MockCreditCardStore()
    private var creditCards: [UUID: CreditCardRecord] = [:]

    init() {
        _ = addRecord(description: "Black Card", cardNumber: "000000000000000", holder: "Jean-Louis Darmon", expirationMonth: 6, expirationYear: 2022)
    }

    func fetchAll() -> [CreditCardRecord] {
        creditCards.values.filter { $0.deletedAt != nil }
    }

    func allRecords(updatedSince: Date?) -> [CreditCardRecord] {
        guard let updatedSince = updatedSince else {
            return Array(creditCards.values)
        }
        return creditCards.values.filter { $0.updatedAt >= updatedSince }
    }

    @discardableResult
    func addRecord(description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int) -> CreditCardRecord {
        var creditCard = CreditCardRecord(cardDescription: description, encryptedCardNumber: cardNumber, cardHolder: holder, expirationMonth: expirationMonth, expirationYear: expirationYear, createdAt: BeamDate.now, updatedAt: BeamDate.now, usedAt: BeamDate.now)
        let uuid = UUID()
        creditCard.uuid = uuid
        creditCards[uuid] = creditCard
        return creditCard
    }

    @discardableResult
    func update(record: CreditCardRecord, description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int) throws -> CreditCardRecord {
        var updatedRecord = try creditCard(matching: record.uuid)
        updatedRecord.cardDescription = description
        updatedRecord.encryptedCardNumber = cardNumber
        updatedRecord.cardHolder = holder
        updatedRecord.expirationMonth = expirationMonth
        updatedRecord.expirationYear = expirationYear
        updatedRecord.updatedAt = BeamDate.now
        updatedRecord.usedAt = BeamDate.now
        creditCards[record.uuid] = updatedRecord
        return updatedRecord
    }

    @discardableResult
    func markUsed(record: CreditCardRecord) throws -> CreditCardRecord {
        var updatedRecord = try creditCard(matching: record.uuid)
        updatedRecord.usedAt = BeamDate.now
        creditCards[record.uuid] = updatedRecord
        return updatedRecord
    }

    @discardableResult
    func markDeleted(record: CreditCardRecord) throws -> CreditCardRecord {
        var updatedRecord = try creditCard(matching: record.uuid)
        if updatedRecord.deletedAt == nil {
            updatedRecord.deletedAt = BeamDate.now
            creditCards[record.uuid] = updatedRecord
        }
        return updatedRecord
    }

    @discardableResult
    func markAllDeleted() throws -> [CreditCardRecord] {
        creditCards = creditCards.mapValues { record in
            var record = record
            if record.deletedAt == nil {
                record.deletedAt = BeamDate.now
            }
            return record
        }
        return Array(creditCards.values)
    }

    @discardableResult
    func deleteAll() throws -> [CreditCardRecord] {
        creditCards.removeAll()
        return []
    }

    private func creditCard(matching uuid: UUID) throws -> CreditCardRecord {
        guard let creditCard = creditCards[uuid] else {
            throw Error.notFound
        }
        return creditCard
    }
}
