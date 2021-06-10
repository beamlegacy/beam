//
//  MockAutocompleteStores.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

class MockUserInformationsStore: UserInformationsStore {
    static let shared = MockUserInformationsStore()

    private var _userInfo: UserInformations?

    init() {
        _userInfo = UserInformations(email: "beam@beam.com", firstName: "John", lastName: "Beam", adresses: "123 Rue de Beam 69001 Lyon")
    }

    func save(userInfo: UserInformations) {
        _userInfo = userInfo
    }

    func get() -> UserInformations {
        return _userInfo ?? UserInformations(email: "", firstName: "", lastName: "", adresses: "")
    }

    func delete() {
        _userInfo = nil
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
