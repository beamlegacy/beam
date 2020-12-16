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
    var id = MonotonicIncreasingID64.newValue
    var source: String = ""
    var title: String = ""
    var language: NLLanguage = .undetermined
    var length: Int = 0
    var contentsWords = [String]()
    var titleWords = [String]()
    var tagsWords = [String]()
}

let gUseLemmas = true

extension IndexDocument {
    init(id: UInt64, source: String, title: String, language: NLLanguage? = nil, contents: String) {
        self.id = id
        self.source = source
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        length = contents.count
        contentsWords = Index.extractWords(from: contents, useLemmas: gUseLemmas)
        titleWords = Index.extractWords(from: title, useLemmas: gUseLemmas)
    }

    var leanCopy: IndexDocument {
        return IndexDocument(id: id, source: source, title: title, language: language, length: length, contentsWords: [], titleWords: [], tagsWords: [])
    }
}

class Index: Codable {
    typealias WordScore = Float

    struct Word: Codable {
        var instances = [UInt64: WordScore]()
        var count: UInt = 0

        // switflint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case instances = "i"
            case count = "c"
        }

    }

    var words: [String: Word] = [:]
    var documents: [UInt64: IndexDocument] = [:]

    init() {
    }

    static let titleScore = Float(1.0)
    static let contentsScore = Float(2.0)

    struct SearchResult {
        var id: UInt64
        var score: Float
        var title: String
        var source: String
    }

    struct DocumentResult: Hashable {
        var id: UInt64
        var score: Float
    }

    func search(string: String) -> [SearchResult] {
        let inputWords = Self.extractWords(from: string, useLemmas: gUseLemmas)

        var results = [UInt64: DocumentResult]()
        let documents = inputWords.map { word -> [DocumentResult] in
            guard let wordMap = words[word] else { return [] }
            return wordMap.instances.map { (key, value) -> Index.DocumentResult in
                return DocumentResult(id: key, score: value)
            }
        }

        for docs in documents {
            for doc in docs {
                var score = doc.score
                if let partialDoc = results[doc.id] {
                    score += partialDoc.score
                }
                results[doc.id] = DocumentResult(id: doc.id, score: score)
            }
        }

        return results.compactMap { doc -> SearchResult? in
            guard let originalDoc = self.documents[doc.key] else { return nil }
            return SearchResult(id: originalDoc.id, score: doc.value.score, title: originalDoc.title, source: originalDoc.source)
        }.sorted { lhs, rhs -> Bool in
            lhs.score > rhs.score
        }
    }

    func append(document: IndexDocument) {
        remove(id: document.id)
        documents[document.id] = document.leanCopy

        for word in document.contentsWords {
            associate(id: document.id, withWord: word, score: Self.contentsScore)
        }

        for word in document.titleWords {
            associate(id: document.id, withWord: word, score: Self.titleScore)
        }
    }

    func associate(id: UInt64, withWord word: String, score: WordScore) {
        guard var ids = words[word] else {
            words[word] = Word(instances: [id: score], count: 1)
            return
        }
        if let oldScore = ids.instances[id] {
            // Add score up as this is a new instance of the word
            ids.instances[id] = oldScore + score
            ids.count += 1
            words[word] = ids
        } else {
            ids.instances[id] = score
            ids.count += 1
            words[word] = ids
        }
    }

    func remove(id: UInt64) {
        guard let oldDoc = documents[id] else { return }
        for word in oldDoc.contentsWords {
            dissociate(id: id, fromWord: word)
        }
        for word in oldDoc.titleWords {
            dissociate(id: id, fromWord: word)
        }
        documents.removeValue(forKey: id)
    }

    func dissociate(id: UInt64, fromWord word: String) {
        guard var ids = words[word] else {
            return
        }
        ids.instances.removeValue(forKey: id)
    }

    func dump() {
        print("Index contains \(words.count) words from \(documents.count) documents")
        for doc in documents {
            print("[Document \(doc.key)] - \(doc.value.title) / \(doc.value.source)")
        }
    }

    class func extractWords(from string: String, useLemmas: Bool) -> [String] {
        // Store the tokenized substrings into an array.
        var wordTokens = [String]()

        // Use Natural Language's NLTagger to tokenize the input by word.
        let tagger = NLTagger(tagSchemes: [.tokenType, .lemma])
        tagger.string = string

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinContractions]

        // Find all tokens in the string and append to the array.
        tagger.enumerateTags(in: string.startIndex..<string.endIndex,
                             unit: .word,
                             scheme: useLemmas ? .lemma : .tokenType,
                             options: options) { (tag, range) -> Bool in
            if useLemmas {
                if let lemma = tag?.rawValue {
                    wordTokens.append(lemma)
                } else {
                    let word = String(string[range].lowercased())
                    wordTokens.append(word)
                    print("no lemma found for word '\(word)'")
                }
            } else {
                wordTokens.append(String(string[range].lowercased()))
            }
            return true
        }

        return wordTokens
    }
}
