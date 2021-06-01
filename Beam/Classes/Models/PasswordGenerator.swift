//
//  PasswordGenerator.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

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
