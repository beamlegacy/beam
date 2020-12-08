//
//  Index.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/12/2020.
//

import Foundation
import NaturalLanguage

extension NLLanguage: Codable {
}

struct IndexDocument: Codable {
    var id = UUID()
    var source: String = ""
    var title: String = ""
    var language: NLLanguage = .undetermined
    var length: Int = 0
    var contentsWords = Set<String>()
    var titleWords = Set<String>()
    var tagsWords = Set<String>()
}

extension IndexDocument {
    init(id: UUID, source: String, title: String, language: NLLanguage? = nil, contents: String) {
        self.id = id
        self.source = source
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        length = contents.count
        contentsWords = extractWords(from: contents)
        titleWords = extractWords(from: title)
    }

    private func extractWords(from string: String) -> Set<String> {
        // Store the tokenized substrings into an array.
        var wordTokens = Set<String>()

        // Use Natural Language's NLTagger to tokenize the input by word.
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = string

        // Find all tokens in the string and append to the array.
        tagger.enumerateTags(in: string.startIndex..<string.endIndex,
                             unit: .word,
                             scheme: .tokenType,
                             options: [.omitWhitespace]) { (_, range) -> Bool in
            wordTokens.insert(String(string[range].lowercased()))
            return true
        }

        return wordTokens
    }
}

class Index: Codable {
    struct WordScore: Codable {
        var score = Float(1.0)
    }

    struct Word: Codable {
        var instances = [UUID: WordScore]()
        var count: UInt = 0
    }

    var words: [String: Word] = [:]
    var documents: [UUID: IndexDocument] = [:]

    init() {
    }

    static let titleScore = Float(1.0)
    static let contentsScore = Float(2.0)

    func append(document: IndexDocument) {
        remove(id: document.id)
        documents[document.id] = document

        for word in document.contentsWords {
            associate(id: document.id, withWord: word, score: WordScore(score: Self.contentsScore))
        }

        for word in document.titleWords {
            associate(id: document.id, withWord: word, score: WordScore(score: Self.titleScore))
        }
    }

    func associate(id: UUID, withWord word: String, score: WordScore) {
        guard var ids = words[word] else {
            words[word] = Word(instances: [id: score], count: 1)
            return
        }
        if let oldScore = ids.instances[id] {
            // Add score up as this is a new instance of the word
            ids.instances[id] = WordScore(score: oldScore.score + score.score)
            ids.count += 1
        } else {
            ids.instances[id] = score
            ids.count += 1
        }
    }

    func remove(id: UUID) {
        guard let oldDoc = documents[id] else { return }
        for word in oldDoc.contentsWords {
            dissociate(id: id, fromWord: word)
        }
        for word in oldDoc.titleWords {
            dissociate(id: id, fromWord: word)
        }
        documents.removeValue(forKey: id)
    }

    func dissociate(id: UUID, fromWord word: String) {
        guard var ids = words[word] else {
            return
        }
        ids.instances.removeValue(forKey: id)
    }

    func dump() {
        print("Index contains \(words.count) words from \(documents.count) documents")
    }
}
