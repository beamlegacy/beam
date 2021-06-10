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

struct UserInformations {
    var email: String
    var firstName: String
    var lastName: String
    var adresses: String
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

protocol UserInformationsStore {
    func save(userInfo: UserInformations)
    func get() -> UserInformations
    func delete()
}
