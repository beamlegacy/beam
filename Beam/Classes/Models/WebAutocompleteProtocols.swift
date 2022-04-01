//
//  WebAutocompleteProtocols.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

struct PasswordManagerEntry: Hashable {
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

struct PasswordManagerHostLookupOptions: OptionSet {
    let rawValue: Int

    static let parentDomains = PasswordManagerHostLookupOptions(rawValue: 1 << 0)
    static let subdomains = PasswordManagerHostLookupOptions(rawValue: 1 << 1)
    static let sharedCredentials = PasswordManagerHostLookupOptions(rawValue: 1 << 2)
    static let genericHost = PasswordManagerHostLookupOptions(rawValue: 1 << 3)

    static let exact: PasswordManagerHostLookupOptions = []
    static let fuzzy: PasswordManagerHostLookupOptions = [.parentDomains, .subdomains, .sharedCredentials, .genericHost]
}

protocol PasswordStore {
    func entries(for hostname: String, options: PasswordManagerHostLookupOptions) throws -> [PasswordRecord]
    func find(_ searchString: String) throws -> [PasswordRecord]
    func fetchAll() throws -> [PasswordRecord]
    func allRecords(_ updatedSince: Date?) throws -> [PasswordRecord]
    func password(hostname: String, username: String) throws -> String?
    func passwordRecord(hostname: String, username: String) throws -> PasswordRecord?
    func save(hostname: String, username: String, password: String, uuid: UUID?) throws -> PasswordRecord
    func save(passwords: [PasswordRecord]) throws
    func update(record: PasswordRecord, hostname: String, username: String, password: String, uuid: UUID?) throws -> PasswordRecord
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
