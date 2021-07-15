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
    func entries(for host: String, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void)
    func password(host: String, username: String, completion: @escaping(String?) -> Void)
    func save(host: String, username: String, password: String)
    func delete(host: String, username: String)
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
