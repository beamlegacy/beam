//
//  Index.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/12/2020.
//

import Foundation
import NaturalLanguage
import BeamCore

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
        self.id = LinkStore.createIdFor(source, title: title)
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        self.outboundLinks = outboundLinks.compactMap({ link -> UInt64? in
            // Only register links that points to cards or to pages we have really visited:
            guard let id = LinkStore.getIdFor(link) else { return nil }
//            guard LinkStore.isInternalLink(id: id) else { return nil }
            return id
        })
        length = contents.count
        contentsWords = contents.extractWords(useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)
        titleWords = title.extractWords(useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)
    }

    var leanCopy: IndexDocument {
        return IndexDocument(id: id, title: title, language: language, length: length, contentsWords: [], titleWords: [], tagsWords: [])
    }
}

struct SearchOptions: OptionSet {
    let rawValue: Int

    static let levenshtein = SearchOptions(rawValue: 1 << 0)
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
    func search(string: String, maxResults: Int? = 10, options: SearchOptions) -> [SearchResult] {
        let inputWords = string.extractWords(useLemmas: gUseLemmas, removeDiacritics: gRemoveDiacritics)

        var results = [UInt64: DocumentResult]()
        let documents = inputWords.map { word -> [DocumentResult] in
            documentsContaining(word: word, maxResults: maxResults, options: options)
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

    var levenshteinCommonSize: Float = 0.8
    var levenshteinCommonLetters: Float = 0.8

    func documentsContaining(word: String, maxResults: Int?, options: SearchOptions) -> [DocumentResult] {
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

            guard options.contains(.levenshtein) else { return [] }

            // the key isn't contained, let's see if we should try levenshtein distance
            // don't try this costly estimation if the words are obviously too different:
            let keyLength = wordkey.count
            guard Float(abs(wordLength - keyLength)) / Float(max(wordLength, keyLength)) < (1.0 - levenshteinCommonSize) else {
                return []
            }

            // Try to see if we have enough similar letters in both words to really try costly levenshtein:
            let set = wordkey.characterSet
            let scoreCount = word.unicodeScalars.reduce(0) { (res, scalar) -> Int in
                res + (set.contains(scalar) ? 1 : 0)
            }
            let score = Float(scoreCount) / Float(word.count)
            if score < levenshteinCommonLetters {
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

    static func loadOrCreate(_ path: URL) -> Index {
        guard FileManager.default.fileExists(atPath: path.absoluteString) else {
            return Index()
        }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            let index = try decoder.decode(Index.self, from: data)
            return index
        } catch {
            Logger.shared.logError("Unable to load index from \(path): \(error)", category: .search)
            return Index()
        }
    }

    func saveTo(_ path: URL) throws {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(self)
        try data?.write(to: path)
    }

    func idf(for word: String) -> Float {
        guard let list = words[word] else { return 0 }
        let docs = Float(documents.count)
        guard docs > 0 else { return 0 }
        let instances = Float(list.instances.count)
        let ratio = docs / instances
        let idf = log(ratio)
        return idf
    }

    func wordFrequency(for document: String) -> [String: Int] {
        var counts = [String: Int]()

        for word in document.extractWords(useLemmas: false, removeDiacritics: true) {
            counts[word] = 1 + (counts[word] ?? 0)
        }

        return counts
    }

    func tfidf(for document: String) -> [String: Float] {
        var tfidf = [String: Float]()
        for word in wordFrequency(for: document) {
            tfidf[word.key] = Float(word.value) * idf(for: word.key)
        }

        return tfidf
    }
}
