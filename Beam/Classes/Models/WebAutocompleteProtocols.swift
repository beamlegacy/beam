//
//  WebAutocompleteProtocols.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

struct PasswordManagerEntry {
    var host: URL
    var username: String
}

struct UserInformations {
    var email: String
    var firstName: String
    var lastName: String
    var adresses: String
}

extension PasswordManagerEntry: Identifiable {
    var id: String {
        "\(host.minimizedHost.isEmpty ? host.absoluteString : host.minimizedHost) \(username)"
    }
}

protocol PasswordStore {
    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void)
    func password(host: URL, username: String, completion: @escaping(String?) -> Void)
    func save(host: URL, username: String, password: String)
    func delete(host: URL, username: String)
}

protocol UserInformationsStore {
    func save(userInfo: UserInformations)
    func get() -> UserInformations
    func delete()
}
