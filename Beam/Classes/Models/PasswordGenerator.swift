//
//  PasswordGenerator.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

import BeamCore

// TODO Add unit tests
class PasswordGenerator {
    static let shared = PasswordGenerator()

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
        guard let wordsFile = WordsFile() else {
            return generatePassword(length: wordCount * 5) // fallback to random character sequence
        }
        let numberPosition = Int.random(in: 0...wordCount) // allows for number-free passphrases
        var passphrase = ""
        for position in 0..<wordCount {
            if !passphrase.isEmpty {
                passphrase += String(symbols.randomElement()!)
            }
            var word = wordsFile.randomWord()
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
}

class WordsFile {
    private var fileHandle: FileHandle
    private var fileLength: UInt64

    init?() {
        guard let fileHandle = FileHandle(forReadingAtPath: "/usr/share/dict/words") else {
            return nil
        }
        self.fileHandle = fileHandle
        do {
            fileLength = try fileHandle.seekToEnd()
        } catch {
            return nil
        }
    }

    deinit {
        try? fileHandle.close()
    }

    func randomWord() -> String {
        while true {
            if let word = randomWord(blockSize: 4096) {
                return word
            }
        }
    }

    private func randomWord(blockSize: Int) -> String? {
        let lastOffset = fileLength - UInt64(blockSize)
        let randomOffset = (0...lastOffset).randomElement()!
        let randomBlock: Data
        do {
            try fileHandle.seek(toOffset: randomOffset)
            guard let data = try fileHandle.read(upToCount: blockSize) else { return nil }
            randomBlock = data
        } catch {
            return nil
        }
        let lineFeed = Character("\n").asciiValue!
        guard let firstLF = randomBlock.firstIndex(of: lineFeed), let lastLF = randomBlock.lastIndex(of: lineFeed) else {
            return nil
        }
        guard let text = String(data: randomBlock.subdata(in: firstLF+1 ..< lastLF), encoding: .utf8) else {
            return nil
        }
        let words = text
            .split(separator: "\n")
            .filter { $0.count >= 4 && $0.count <= 8 }
            .map { $0.lowercased() }
        guard !words.isEmpty else {
            return nil
        }
        // Returning the first word would introduce a bias (words directly following long words would be more likely to appear).
        // The bias is mitigated by returning a random word from the block.
        return words.randomElement()
    }
}
