//
//  WebAutocompleteProtocols.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

struct PasswordManagerEntry {
    var minimizedHost: String
    var username: String
}

struct Credential {
    var username: String
    var password: String
}

extension PasswordManagerEntry {
    init(host: URL, username: String) {
        self.minimizedHost = host.minimizedHost ?? host.urlStringWithoutScheme
        self.username = username
    }
}

extension PasswordManagerEntry: Identifiable {
    var id: String {
        "\(minimizedHost) \(username)"
    }
}

protocol PasswordStore {
    func entries(for hostname: String, exact: Bool) throws -> [PasswordRecord]
    func find(_ searchString: String) throws -> [PasswordRecord]
    func fetchAll() throws -> [PasswordRecord]
    func allRecords(_ updatedSince: Date?) throws -> [PasswordRecord]
    func password(hostname: String, username: String) throws -> String?
    func passwordRecord(hostname: String, username: String) throws -> PasswordRecord?
    func save(hostname: String, username: String, password: String, uuid: UUID?) throws -> PasswordRecord
    func save(passwords: [PasswordRecord]) throws
    func update(record: PasswordRecord, password: String, uuid: UUID?) throws -> PasswordRecord
    @discardableResult func markDeleted(hostname: String, username: String) throws -> PasswordRecord
    @discardableResult func markAllDeleted() throws -> [PasswordRecord]
    @discardableResult func deleteAll() throws -> [PasswordRecord]
    func credentials(for hostname: String, completion: @escaping ([Credential]) -> Void)
}

struct UserInformations: Identifiable {
    var id = UUID()
    var country: Int?
    var organization: String?
    var firstName: String?
    var lastName: String?
    var adresses: String?
    var postalCode: String?
    var city: String?
    var phone: String?
    var email: String?
}

protocol UserInformationsStore {
    func save(userInfo: UserInformations)
    func update(userInfoUUIDToUpdate: UUID, updatedUserInformations: UserInformations)
    func fetchAll() -> [UserInformations]
    func fetchFirst() -> UserInformations
    func delete(id: UUID)
}

struct CreditCard {
    var id = UUID()
    var cardDescription: String
    var cardNumber: Int
    var cardHolder: String
    var cardDate: Date
}

protocol CreditCardsStore {
    func save(creditCard: CreditCard)
    func fetchAll() -> [CreditCard]
    func update(id: UUID, creditCard: CreditCard)
    func delete(id: UUID)
}
