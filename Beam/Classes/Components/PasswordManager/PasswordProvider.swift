//
//  PasswordProvider.swift
//  Beam
//
//  Created by Frank Lefebvre on 30/03/2021.
//

import Foundation
import Combine

struct PasswordManagerEntry {
    var host: URL
    var username: String
}

extension PasswordManagerEntry: Identifiable {
    var id: String {
        "\(host.minimizedHost) \(username)"
    }
}

protocol PasswordStore {
    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void)
    func password(host: URL, username: String, completion: @escaping(String?) -> Void)
    func save(host: URL, username: String, password: String)
    func delete(host: URL, username: String)
}

class MockPasswordStore: PasswordStore {
    static let shared = MockPasswordStore()

    private var entries: [PasswordManagerEntry]
    private var passwords: [String: String]

    init() {
        entries = [
            "https://macg.co",
            "https://github.com",
            "https://apple.com"
        ].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "toto@mail.net")
        }
        entries += [
            "https://macg.co",
            "https://objc.io"
        ].map {
            PasswordManagerEntry(host: URL(string: $0)!, username: "titi@mail.net")
        }
        passwords = entries.enumerated().reduce(into: [:], { (dict, iter) in
            dict[iter.1.id] = "password\(iter.0)"
        })
    }

    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        let results = entries.filter {
            $0.host.minimizedHost == host.minimizedHost
        }
        completion(results)
    }

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        let results = entries.filter {
            $0.id.contains(searchString)
        }
        completion(results)
    }

    func password(host: URL, username: String, completion: @escaping (String?) -> Void) {
        let id = PasswordManagerEntry(host: host, username: username).id
        completion(passwords[id])
    }

    func save(host: URL, username: String, password: String) {
        delete(host: host, username: username)
        let entry = PasswordManagerEntry(host: host, username: username)
        entries.append(entry)
        passwords[entry.id] = password
    }

    func delete(host: URL, username: String) {
        let id = PasswordManagerEntry(host: host, username: username).id
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
        }
        passwords[id] = nil
    }
}

// TODO Add unit tests
class PasswordGenerator {
    static let shared = PasswordGenerator()

    lazy var words = Self.makeWordList()
    let lowercase = "abcdefghijkmnopqrstuvwxyz" // without "l"
    let uppercase = "ABCDEFGHIJKLMNPQRSTUVWXYZ" // without "O"
    let digits = "123456789" // without "0"
    let symbols = "&()+-*/%#@!?.:,;="

    func generatePassword(length: Int) -> String {
        var password = ""
        for _ in 0..<length {
            let nextChar: Character
            switch Int.random(in: 0..<10) {
            case 0:
                nextChar = symbols.randomElement()!
            case 1:
                nextChar = digits.randomElement()!
            case 2, 3:
                nextChar = uppercase.randomElement()!
            default:
                nextChar = lowercase.randomElement()!
            }
            password += String(nextChar)
        }
        return password
    }

    func generatePassphrase(wordCount: Int) -> String {
        let numberPosition = Int.random(in: 0...wordCount) // allows for number-free passphrases
        var passphrase = ""
        for position in 0..<wordCount {
            if !passphrase.isEmpty {
                passphrase += String(symbols.randomElement()!)
            }
            var word = words.randomElement()!
            if Int.random(in: 0..<wordCount) == 0 {
                word = word.uppercased()
            }
            passphrase += word
            if position == numberPosition {
                passphrase += String(Int.random(in: 0...99))
            }
        }
        return passphrase
    }

    private static func makeWordList() -> [String] {
        let wordsFile = URL(fileURLWithPath: "/usr/share/dict/words")
        do {
            let words = try String(contentsOf: wordsFile, encoding: .utf8)
                .split(separator: "\n")
                .filter { $0.count >= 4 && $0.count <= 8 }
                .map { $0.lowercased() }
            return words
        } catch {
            return [] // TODO: disable passphrase generator
        }
    }
}
