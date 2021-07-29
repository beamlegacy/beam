//
//  MockAutocompleteStores.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

class MockCreditCardStore: CreditCardsStore {

    static let shared = MockCreditCardStore()
    private var creditCards: [CreditCard] = []

    init() {
        creditCards.append(CreditCard(cardDescription: "Black Card", cardNumber: 000000000000000, cardHolder: "Jean-Louis Darmon", cardDate: Date()))
    }

    func save(creditCard: CreditCard) {
        creditCards.append(creditCard)
    }

    func fetchAll() -> [CreditCard] {
        return creditCards
    }

    func update(id: UUID, creditCard: CreditCard) {
        var creditCardUpdated = creditCard
        creditCardUpdated.id = id
    }

    func delete(id: UUID) {
        if let index = creditCards.firstIndex(where: {$0.id == id}) {
            creditCards.remove(at: index)
        }
    }
}

class MockUserInformationsStore: UserInformationsStore {

    static let shared = MockUserInformationsStore()

    private var userInformations: [UserInformations] = []

    init() {
        userInformations.append(UserInformations(country: 1,
                                                 organization: "Beam",
                                                 firstName: "John",
                                                 lastName: "BeamBeam",
                                                 adresses: "123 Rue de Beam",
                                                 postalCode: "69001",
                                                 city: "BeamCity",
                                                 phone: "0628512605",
                                                 email: "john@beamapp.co"))
    }

    func save(userInfo: UserInformations) {
        userInformations.append(userInfo)
    }

    func update(userInfoUUIDToUpdate: UUID, updatedUserInformations: UserInformations) {
        var userInfoUpdated = updatedUserInformations
        userInfoUpdated.id = userInfoUUIDToUpdate
        // update userInfoUpdated
    }

    func fetchAll() -> [UserInformations] {
        return userInformations
    }

    func fetchFirst() -> UserInformations {
        guard let userInfo = self.userInformations.first else {
            return UserInformations(country: 1,
                                    organization: "Beam",
                                    firstName: "John",
                                    lastName: "BeamBeam",
                                    adresses: "123 Rue de Beam",
                                    postalCode: "69001",
                                    city: "BeamCity",
                                    phone: "0628512605",
                                    email: "john@beamapp.co")
        }
        return userInfo
    }

    func delete(id: UUID) {
        if let index = userInformations.firstIndex(where: {$0.id == id}) {
            userInformations.remove(at: index)
        }
    }
}

class MockPasswordStore: PasswordStore {
    static let shared = MockPasswordStore()

    private var entries: [PasswordManagerEntry]
    private var passwords: [String: String]

    init() {
        entries = [
            "http://mock1.beam",
            "http://mock2.beam",
            "http://mock3.beam",
            "http://mock4.beam",
            "http://mock5.beam",
            "https://macg.co",
            "https://github.com",
            "https://apple.com"
        ].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "toto@mail.net")
        }
        entries += ["https://github.com"].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "toto2@mail.net")
        }
        entries += ["https://github.com"].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "toto3@mail.net")
        }
        entries += ["https://github.com"].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "toto4@mail.net")
        }
        entries += [
            "http://mock1.beam",
            "https://macg.co",
            "https://objc.io"
        ].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "titi@mail.net")
        }
        passwords = entries.enumerated().reduce(into: [:], { (dict, iter) in
            dict[iter.1.id] = "password\(iter.0)"
        })
    }

    func entries(for host: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        let results = entries.filter {
            $0.minimizedHost == host
        }
        completion(results)
    }

    func entriesWithSubdomains(for host: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        let results = entries.filter {
            $0.minimizedHost == host || $0.minimizedHost.hasSuffix(".\(host)")
        }
        completion(results)
    }

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        let results = entries.filter {
            $0.id.contains(searchString)
        }
        completion(results)
    }

    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void) {
        completion(entries)
    }

    func password(host: String, username: String, completion: @escaping (String?) -> Void) {
        let id = PasswordManagerEntry(minimizedHost: host, username: username).id
        completion(passwords[id])
    }

    func save(host: String, username: String, password: String) {
        delete(host: host, username: username)
        let entry = PasswordManagerEntry(minimizedHost: host, username: username)
        entries.append(entry)
        passwords[entry.id] = password
    }

    func delete(host: String, username: String) {
        let id = PasswordManagerEntry(minimizedHost: host, username: username).id
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
        }
        passwords[id] = nil
    }
}
