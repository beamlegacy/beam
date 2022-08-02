//
//  CreditCardsDB.swift
//  Beam
//
//  Created by Beam on 13/04/2022.
//

import Foundation
import BeamCore
import GRDB

enum CreditCardsDBError: Error {
    case cantReadDB(errorMsg: String)
    case cantDecrypt(errorMsg: String)
    case cantSave(errorMsg: String)
    case cantEncryptCardNumber
    case cantDelete(errorMsg: String)
    case errorFetchingCreditCards(errorMsg: String)
    case errorSearchingCreditCards(errorMsg: String)
}

struct CreditCardRecord {
    internal static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString

    var uuid: UUID = .null
    var cardDescription: String
    var encryptedCardNumber: String
    var cardHolder: String
    var expirationMonth: Int
    var expirationYear: Int
    var createdAt: Date
    var updatedAt: Date
    var usedAt: Date
    var deletedAt: Date?
    var privateKeySignature: String?
}

extension CreditCardRecord: BeamObjectProtocol {
    static let beamObjectType = BeamObjectObjectType.creditCard

    var beamObjectId: UUID {
        get { uuid }
        set { uuid = newValue }
    }

    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
        case cardDescription
        case encryptedCardNumber = "cardNumber"
        case cardHolder
        case expirationMonth
        case expirationYear
        case createdAt
        case updatedAt
        case usedAt
        case deletedAt
        case privateKeySignature
    }

    func copy() -> CreditCardRecord {
        CreditCardRecord(cardDescription: cardDescription,
                         encryptedCardNumber: encryptedCardNumber,
                         cardHolder: cardHolder,
                         expirationMonth: expirationMonth,
                         expirationYear: expirationYear,
                         createdAt: createdAt,
                         updatedAt: updatedAt,
                         usedAt: usedAt,
                         deletedAt: deletedAt,
                         privateKeySignature: privateKeySignature)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        cardDescription = try container.decode(String.self, forKey: .cardDescription)
        encryptedCardNumber = try container.decode(String.self, forKey: .encryptedCardNumber)
        cardHolder = try container.decode(String.self, forKey: .cardHolder)
        expirationMonth = try container.decode(Int.self, forKey: .expirationMonth)
        expirationYear = try container.decode(Int.self, forKey: .expirationYear)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        usedAt = try container.decode(Date.self, forKey: .usedAt)
        deletedAt = try? container.decode(Date.self, forKey: .deletedAt)
        privateKeySignature = try? container.decode(String.self, forKey: .privateKeySignature)
    }
}

extension CreditCardRecord: Equatable { }

extension CreditCardRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case uuid, cardDescription, cardNumber, cardHolder, expirationMonth, expirationYear, createdAt, updatedAt, usedAt, deletedAt, privateKeySignature
    }
}

// Fetching
extension CreditCardRecord: FetchableRecord {
    init(row: Row) {
        uuid = row[Columns.uuid]
        cardDescription = row[Columns.cardDescription]
        encryptedCardNumber = row[Columns.cardNumber]
        cardHolder = row[Columns.cardHolder]
        expirationMonth = row[Columns.expirationMonth]
        expirationYear = row[Columns.expirationYear]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        usedAt = row[Columns.usedAt]
        deletedAt = row[Columns.deletedAt]
        privateKeySignature = row[Columns.privateKeySignature]
    }
}

// Persisting
extension CreditCardRecord: MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.uuid] = uuid
        container[Columns.cardDescription] = cardDescription
        container[Columns.cardNumber] = encryptedCardNumber
        container[Columns.cardHolder] = cardHolder
        container[Columns.expirationMonth] = expirationMonth
        container[Columns.expirationYear] = expirationYear
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.usedAt] = usedAt
        container[Columns.deletedAt] = deletedAt
        container[Columns.privateKeySignature] = privateKeySignature
    }
}

// Encryption
extension CreditCardRecord {
    func decryptedCardNumber() throws -> String {
        do {
            let cardNumber = try EncryptionManager.shared.decryptString(encryptedCardNumber, EncryptionManager.shared.localPrivateKey())
            return cardNumber ?? ""
        } catch {
            throw CreditCardsDBError.cantDecrypt(errorMsg: error.localizedDescription)
        }
    }
}

class CreditCardsDB: GRDBHandler, CreditCardStore, BeamManager, LegacyAutoImportDisabler {
    static var name = "CreditCardsDB"
    weak var holder: BeamManagerOwner?
    override var tableNames: [String] { [CreditCardsDB.tableName] }

    static let id = UUID()
    static let tableName = "creditCardRecord"
    var grdbStore: GRDBStore

    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        self.grdbStore = store

        try super.init(store: store)
    }

    override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("creditCardTableCreation") { db in
            try db.create(table: CreditCardsDB.tableName, ifNotExists: true) { table in
                table.column("uuid", .text).notNull().primaryKey().unique()
                table.column("cardDescription", .text).notNull()
                table.column("cardNumber", .text).notNull()
                table.column("cardHolder", .text).notNull()
                table.column("expirationMonth", .integer).notNull()
                table.column("expirationYear", .integer).notNull()
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("usedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("privateKeySignature", .text).notNull()
            }
        }
    }

    func fetchRecord(uuid: UUID) throws -> CreditCardRecord? {
        do {
            return try read { db in
                return try CreditCardRecord.filter(CreditCardRecord.Columns.uuid == uuid).fetchOne(db)
            }
        } catch {
            throw CreditCardsDBError.errorFetchingCreditCards(errorMsg: error.localizedDescription)
        }
    }

    func fetchAll() throws -> [CreditCardRecord] {
        do {
            return try read { db in
                try CreditCardRecord
                    .filter(CreditCardRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
            }
        } catch {
            throw CreditCardsDBError.errorFetchingCreditCards(errorMsg: error.localizedDescription)
        }
    }

    func allRecords(updatedSince: Date? = nil) throws -> [CreditCardRecord] {
        do {
            return try read { db in
                if let updatedSince = updatedSince {
                    return try CreditCardRecord.filter(CreditCardRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
                }
                return try CreditCardRecord.fetchAll(db)
            }
        } catch {
            throw CreditCardsDBError.errorFetchingCreditCards(errorMsg: error.localizedDescription)
        }
    }

    func find(_ searchString: String) throws -> [CreditCardRecord] {
        do {
            return try read { db in
                return try CreditCardRecord
                    .filter(CreditCardRecord.Columns.cardDescription.like("%\(searchString)%") && CreditCardRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
            }
        } catch {
            throw CreditCardsDBError.errorSearchingCreditCards(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func addRecord(description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int) throws -> CreditCardRecord {
        do {
            return try write { db in
                guard let encryptedCardNumber = try? EncryptionManager.shared.encryptString(cardNumber, EncryptionManager.shared.localPrivateKey()) else {
                    throw CreditCardsDBError.cantEncryptCardNumber
                }
                let privateKeySignature = try EncryptionManager.shared.localPrivateKey().asString().SHA256()
                var creditCardRecord = CreditCardRecord(
                    uuid: UUID(),
                    cardDescription: description,
                    encryptedCardNumber: encryptedCardNumber,
                    cardHolder: holder,
                    expirationMonth: expirationMonth,
                    expirationYear: expirationYear,
                    createdAt: BeamDate.now,
                    updatedAt: BeamDate.now,
                    usedAt: BeamDate.now,
                    deletedAt: nil,
                    privateKeySignature: privateKeySignature)
                try creditCardRecord.insert(db)
                return creditCardRecord
            }
        } catch {
            throw CreditCardsDBError.cantSave(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func update(record: CreditCardRecord, description: String, cardNumber: String, holder: String, expirationMonth: Int, expirationYear: Int) throws -> CreditCardRecord {
        do {
            return try write { db in
                guard let encryptedCardNumber = try? EncryptionManager.shared.encryptString(cardNumber, EncryptionManager.shared.localPrivateKey()) else {
                    throw CreditCardsDBError.cantEncryptCardNumber
                }
                let privateKeySignature = try EncryptionManager.shared.localPrivateKey().asString().SHA256()
                var updatedRecord = record
                updatedRecord.cardDescription = description
                updatedRecord.encryptedCardNumber = encryptedCardNumber
                updatedRecord.cardHolder = holder
                updatedRecord.expirationMonth = expirationMonth
                updatedRecord.expirationYear = expirationYear
                updatedRecord.updatedAt = BeamDate.now
                updatedRecord.usedAt = BeamDate.now
                updatedRecord.privateKeySignature = privateKeySignature
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch {
            throw CreditCardsDBError.cantSave(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func markUsed(record: CreditCardRecord) throws -> CreditCardRecord {
        do {
            return try write { db in
                var updatedRecord = record
                updatedRecord.usedAt = BeamDate.now
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch {
            throw CreditCardsDBError.cantSave(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func markDeleted(record: CreditCardRecord) throws -> CreditCardRecord {
        do {
            return try write { db in
                var updatedRecord = record
                updatedRecord.deletedAt = BeamDate.now
                updatedRecord.updatedAt = BeamDate.now
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch {
            throw CreditCardsDBError.cantDelete(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func markAllDeleted() throws -> [CreditCardRecord] {
        do {
            return try write { db in
                let now = BeamDate.now
                try CreditCardRecord
                    .filter(Column("deletedAt") == nil)
                    .updateAll(db, Column("deletedAt").set(to: now), Column("updatedAt").set(to: now))

                let records = try CreditCardRecord
                    .filter(CreditCardRecord.Columns.deletedAt == now)
                    .fetchAll(db)
                return records
            }
        } catch {
            throw CreditCardsDBError.cantDelete(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func deleteAll() throws -> [CreditCardRecord] {
        do {
            return try write { db in
                try CreditCardRecord.deleteAll(db)
                return []
            }
        } catch {
            throw CreditCardsDBError.cantDelete(errorMsg: error.localizedDescription)
        }
    }
}

extension BeamManagerOwner {
    var creditCardsDB: CreditCardsDB? {
        try? manager(CreditCardsDB.self)
    }
}

extension BeamData {
    var creditCardsDB: CreditCardsDB? {
        currentAccount?.creditCardsDB
    }
}
