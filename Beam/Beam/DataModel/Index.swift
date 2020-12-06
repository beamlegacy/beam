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
    var words = Set<String>()
}

extension IndexDocument {
    init(id: UUID, source: String, title: String, language: NLLanguage? = nil, contents: String) {
        self.id = id
        self.source = source
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        length = contents.count
        words = Set<String>(extractWords(from: contents))
    }

    private func extractWords(from string: String) -> [String] {
        // Store the tokenized substrings into an array.
        var wordTokens = [String]()

        // Use Natural Language's NLTagger to tokenize the input by word.
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = string

        // Find all tokens in the string and append to the array.
        tagger.enumerateTags(in: string.startIndex..<string.endIndex,
                             unit: .word,
                             scheme: .tokenType,
                             options: [.omitWhitespace]) { (_, range) -> Bool in
            wordTokens.append(String(string[range]))
            return true
        }

        return wordTokens
    }
}

class Index: Codable {
    var words: [String: Set<UUID>] = [:]
    var documents: [UUID: IndexDocument]

    func append(document: IndexDocument) {
        remove(id: document.id)
        documents[document.id] = document

        for word in document.words {
            associate(id: document.id, withWord: word)
        }
    }

    func associate(id: UUID, withWord word: String) {
        guard var ids = words[word] else {
            words[word] = Set<UUID>([id])
            return
        }
        ids.insert(id)
    }

    func remove(id: UUID) {
        guard let oldDoc = documents[id] else { return }
        for word in oldDoc.words {
            dissociate(id: id, fromWord: word)
        }
        documents.removeValue(forKey: id)
    }

    func dissociate(id: UUID, fromWord word: String) {
        guard var ids = words[word] else {
            return
        }
        ids.remove(id)
    }
}
