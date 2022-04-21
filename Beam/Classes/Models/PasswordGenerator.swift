//
//  PasswordGenerator.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/05/2021.
//

import BeamCore

class PasswordGenerator {
    static let shared = PasswordGenerator()

    private static let lowercaseConsonants = "bcdfghjkmnpqrstvwxz" // without "l"
    private static let lowercaseVowels = "aeiouy"
    private static let uppercaseConsonants = "BCDFGHJKLMNPQRSTVWXZ"
    private static let uppercaseVowels = "AEUY" // without "I" and "O"
    private static let digits = "123456789" // without "0"
    private static let symbols = "&()+-*/%#@!?.:,;="

    private enum TrigramPosition: Int, CaseIterable {
        case left
        case middle
        case right
    }

    private struct Trigram {
        private var storage: [Character]

        private init(_ left: Character, _ middle: Character, _ right: Character) {
            storage = [left, middle, right]
        }

        var string: String {
            String(storage)
        }

        static func random() -> Self {
            guard let left = lowercaseConsonants.randomElement(), let middle = lowercaseVowels.randomElement(), let right = lowercaseConsonants.randomElement() else {
                fatalError()
            }
            return .init(left, middle, right)
        }

        mutating func insertDigit() {
            guard let position = TrigramPosition.allCases.randomElement(), let digit = digits.randomElement() else { fatalError() }
            storage[position.rawValue] = digit
        }

        mutating func insertUppercase() {
            guard let position = TrigramPosition.allCases.randomElement(), let consonant = uppercaseConsonants.randomElement(), let vowel = uppercaseVowels.randomElement() else { fatalError() }
            switch position {
            case .left, .right:
                storage[position.rawValue] = consonant
            case .middle:
                storage[position.rawValue] = vowel
            }
        }
    }

    /// Generate Safari-like password:
    /// 3 blocks of 6 characters, alternating consonants and vowels (cvccvc), with 1 uppercase letter + 1 digit
    /// Entropy: 73 bits
    func generatePassword(blockCount: Int = 3) -> String {
        let trigramCount = blockCount * 2
        var trigrams = (0..<trigramCount).map { _ in Trigram.random() }
        trigrams[0].insertDigit()
        trigrams[1].insertUppercase()
        trigrams.shuffle()
        return trigrams.reduce(into: "") { string, trigram in
            if string.count % 7 == 6 {
                string += "-"
            }
            string += trigram.string
        }
    }

    func generatePassphrase(wordCount: Int) -> String {
        guard let wordsFile = WordsFile() else {
            return generatePassword() // fallback to random character sequence
        }
        let numberPosition = Int.random(in: 0...wordCount) // allows for number-free passphrases
        var passphrase = ""
        for position in 0..<wordCount {
            if !passphrase.isEmpty {
                passphrase += String(Self.symbols.randomElement()!)
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
