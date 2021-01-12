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
    var id: UInt64
    var title: String = ""
    var language: NLLanguage = .undetermined
    var length: Int = 0
    var contentsWords = [String]()
    var titleWords = [String]()
    var tagsWords = [String]()
    var outboundLinks = [UInt64]()

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case title = "t"
    }
}

let gUseLemmas = false
let gRemoveDiacritics = true

extension IndexDocument {
    init(source: String, title: String, language: NLLanguage? = nil, contents: String, outboundLinks: [String] = []) {
        self.id = LinkStore.createIdFor(source)
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        self.outboundLinks = outboundLinks.compactMap({ link -> UInt64? in
            // Only register links that points to cards or to pages we have really visited:
            guard let id = LinkStore.getIdFor(link) else { return nil }
//            guard LinkStore.isInternalLink(id: id) else { return nil }
            return id
        })
        length = contents.count
        contentsWords = Index.extractWords(from: contents, useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)
        titleWords = Index.extractWords(from: title, useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)
    }

    var leanCopy: IndexDocument {
        return IndexDocument(id: id, title: title, language: language, length: length, contentsWords: [], titleWords: [], tagsWords: [])
    }
}

class Index: Codable {
    typealias WordScore = Float

    struct Word: Codable {
        var instances = [UInt64: WordScore]()
        var count: UInt = 0

        //swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case instances = "i"
            case count = "c"
        }

    }

    var words: [String: Word] = [:]
    var documents: [UInt64: IndexDocument] = [:]
    var pageRank = PageRank()

    enum CodingKeys: String, CodingKey {
        case words, documents, pageRank
    }

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

    var partialResults: [String: [DocumentResult]] = [:]

    //swiftlint:disable:next cyclomatic_complexity
    func search(string: String, maxResults: Int? = 10) -> [SearchResult] {
        let inputWords = Self.extractWords(from: string, useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)

        var results = [UInt64: DocumentResult]()
        let documents = inputWords.map { word -> [DocumentResult] in
            documentsContaining(word: word, maxResults: maxResults)
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
            guard let source = LinkStore.linkFor(originalDoc.id)?.url else { return nil }
            return SearchResult(id: originalDoc.id, score: doc.value.score, title: originalDoc.title, source: source)
        }.sorted { lhs, rhs -> Bool in
            lhs.score > rhs.score
        }
    }

    func documentsContaining(word: String, maxResults: Int?) -> [DocumentResult] {
        if let partialResult = partialResults[word] {
            return partialResult
        }

        var documents: [DocumentResult] = []

        defer {
            partialResults[word] = documents
        }

        let wordLength = word.count
        if let wordMap = words[word] {
            documents += wordMap.instances.map { (key, value) -> Index.DocumentResult in DocumentResult(id: key, score: value) }

            // do we have enough exact results for this word?
            if documents.count > maxResults ?? .max {
                return documents
            }
        }

        documents += words.compactMap { wordkey, value -> [Index.DocumentResult] in
            if wordkey.contains(word) {
                return value.instances.map { (key, value) -> Index.DocumentResult in
                    let score = value * (Float(wordLength) / Float(wordkey.count))
                    return DocumentResult(id: key, score: score) }
            }

            // the key isn't contained, let's see if we should try levenshtein distance
            // don't try this costly estimation if the words are obviously too different:
            let keyLength = wordkey.count
            guard Float(abs(wordLength - keyLength)) / Float(max(wordLength, keyLength)) < 0.2 else {
                return []
            }
            let distance = word.levenshtein(wordkey)
            guard distance < 4, distance > 0 else { return [] }
            let ratio: [Float] = [0, 0.95, 0.70, 0.6, 0.3]
            return value.instances.map { (key, value) -> Index.DocumentResult in DocumentResult(id: key, score: value / ratio[distance]) }
        }.joined()

        if documents.count > maxResults ?? .max {
            return documents
        }

        return documents

    }

    func append(document: IndexDocument) {
        partialResults.removeAll()
        remove(id: document.id)
        documents[document.id] = document.leanCopy

        for word in document.contentsWords {
            associate(id: document.id, withWord: word, score: Self.contentsScore)
        }

        for word in document.titleWords {
            associate(id: document.id, withWord: word, score: Self.titleScore)
        }

        if let source = LinkStore.linkFor(document.id)?.url, LinkStore.isInternal(link: source) {
            pageRank.updatePage(source: source, outbounds: document.outboundLinks)
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
        partialResults.removeAll()
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
        Logger.shared.logInfo("Index contains \(words.count) words from \(documents.count) documents", category: .search)
        for doc in documents {
            Logger.shared.logInfo("[Document \(doc.key)] - \(doc.value.title) / \(String(describing: LinkStore.linkFor(doc.value.id)))", category: .search)
        }
    }

    class func extractWords(from string: String, useLemmas: Bool, removeDiacritics: Bool) -> [String] {
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
                    wordTokens.append(removeDiacritics ? lemma.folding(options: .diacriticInsensitive, locale: .current) : lemma)
                } else {
                    let word = String(string[range].lowercased())
                    wordTokens.append(removeDiacritics ? word.folding(options: .diacriticInsensitive, locale: .current) : word)
                    //print("no lemma found for word '\(word)'")
                }
            } else {
                let word = String(string[range].lowercased())
                wordTokens.append(removeDiacritics ? word.folding(options: .diacriticInsensitive, locale: .current) : word)
            }
            return true
        }

        return wordTokens
    }

    static func loadOrCreate(_ path: URL) -> Index {
        guard let data = try? Data(contentsOf: path) else {
            Logger.shared.logError("Unable to load index from \(path)", category: .search)
            return Index()
        }
        let decoder = JSONDecoder()
        guard let index = try? decoder.decode(Index.self, from: data) else {
            Logger.shared.logError("Unable to decode index from \(path)", category: .search)
            return Index()
        }
        return index
    }

    func saveTo(_ path: URL) throws {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(self)
        try data?.write(to: path)
    }
}
