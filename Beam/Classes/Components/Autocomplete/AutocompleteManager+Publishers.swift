//
//  AutocompleteManager+Publishers.swift
//  Beam
//
//  Created by Remi Santos on 16/07/2021.
//

import Foundation
import Combine
import BeamCore

extension AutocompleteManager {
    typealias AutocompletePublisherSourceResults = (source: AutocompleteResult.Source, results: [AutocompleteResult])

    private func logIntermediate(step: String, stepShortName: String, results: [AutocompleteResult]) {
        Self.logIntermediate(step: step, stepShortName: stepShortName, results: results)
    }

    func getDefaultSuggestionsPublishers() -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        [
            // Default suggestions will be improved in a upcoming ticket
            futureToPublisher(defaultSuggestionsNotesResults(), source: .note)
        ]
    }

    func getAutocompletePublishers(for searchText: String) -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        [
            futureToPublisher(autocompleteNotesResults(for: searchText), source: .note),
            futureToPublisher(autocompleteNotesContentsResults(for: searchText), source: .note),
            futureToPublisher(autocompleteTopDomainResults(for: searchText), source: .topDomain),
            futureToPublisher(autocompleteHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteAliasHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteLinkStoreResults(for: searchText), source: .url),
            self.autocompleteCanCreateNoteResult(for: searchText)
                .replaceError(with: false)
                .map { canCreate in
                    let createResult = AutocompleteResult(text: searchText,
                                                          source: .createCard,
                                                          information: "New card",
                                                          completingText: searchText)
                    let results = canCreate ? [createResult] : []
                    return (AutocompleteResult.Source.createCard, results)
                }.eraseToAnyPublisher()
        ]
    }

    func getSearchEnginePublisher(for searchText: String,
                                  searchEngine: Autocompleter) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        futureToPublisher(autocompleteSearchEngineResults(for: searchText, searchEngine: searchEngine), source: .autocomplete).handleEvents(receiveCancel: { [weak searchEngine] in
            searchEngine?.clear()
        }).eraseToAnyPublisher()
    }

    private func futureToPublisher(_ future: Future<[AutocompleteResult], Error>,
                                   source: AutocompleteResult.Source) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        future
            .catch { error -> AnyPublisher<[AutocompleteResult], Never> in
                // catch the error while not stopping the publisher chain
                Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                return Just([]).eraseToAnyPublisher()
            }
            .map { someResults in
                return (source, someResults)
            }
            .eraseToAnyPublisher()
    }

    private func autocompleteNotesResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            let documentManager = DocumentManager()
            documentManager.documentsWithTitleMatch(title: query) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let documentStructs):
                    let ids = documentStructs.map { $0.id }
                    let scores = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey)
                    let autocompleteResults = documentStructs.map {
                        AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: query, uuid: $0.id, score: scores[$0.id])
                    }.sorted(by: >).prefix(6)
                    let autocompleteResultsArray = Array(autocompleteResults)
                    self?.logIntermediate(step: "NoteTitle", stepShortName: "NT", results: autocompleteResultsArray)
                    promise(.success(autocompleteResultsArray))
                }
            }
        }
    }

    private func autocompleteNotesContentsResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            GRDBDatabase.shared.search(matchingAllTokensIn: query, maxResults: 10, frecencyParam: AutocompleteManager.noteFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let notesContentResults):
                    let documentManager = DocumentManager()
                    let ids = notesContentResults.map { $0.noteId }
                    let docs = documentManager.loadDocumentsById(ids: ids)
                    let autocompleteResults = notesContentResults.compactMap { result -> AutocompleteResult? in
                        // Check if the note still exists before proceeding.
                        guard docs.first(where: { $0.id == result.noteId }) != nil else { return nil }
                        return AutocompleteResult(text: result.title, source: .note(noteId: result.noteId, elementId: result.uid),
                                                  completingText: query, uuid: result.uid, score: result.frecency?.frecencySortScore)
                    }
                    self.logIntermediate(step: "NoteContent", stepShortName: "NC", results: autocompleteResults)
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteHistoryResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            GRDBDatabase.shared.searchHistory(query: query, enabledFrecencyParam: AutocompleteManager.urlFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let historyResults):
                    let autocompleteResults = historyResults.map { result -> AutocompleteResult in
                        var information: String? = result.url
                        let url = URL(string: result.url)
                        if let url = url {
                            information = url.urlStringWithoutScheme.removingPercentEncoding
                        }
                        return AutocompleteResult(text: result.title, source: .history,
                                                  url: url, information: information, completingText: query, score: result.frecency?.frecencySortScore)
                    }
                    self.logIntermediate(step: "HistoryContent", stepShortName: "HC", results: autocompleteResults)
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteAliasHistoryResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            GRDBDatabase.shared.searchAlias(query: query, enabledFrecencyParam: AutocompleteManager.urlFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let historyResult):
                    guard let historyResult = historyResult else {
                        promise(.success([]))
                        return
                    }
                    var information: String? = historyResult.url
                    let url = URL(string: historyResult.url)
                    if let url = url {
                        information = url.urlStringWithoutScheme.removingPercentEncoding
                    }
                    promise(.success([AutocompleteResult(text: historyResult.title,
                                                         source: .history,
                                                         url: url,
                                                         information: information,
                                                         completingText: query,
                                                         score: historyResult.frecency?.frecencySortScore)
                                     ]))
                }
            }
        }
    }

    private func autocompleteLinkStoreResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let links = LinkStore.shared.getLinks(matchingUrl: query)
            let scores = GRDBDatabase.shared.getFrecencyScoreValues(urlIds: Array(links.keys), paramKey: AutocompleteManager.urlFrecencyParamKey)
            let results = links.map { (urlId, link) -> AutocompleteResult in
                let url = URL(string: link.url)
                let text = url?.urlStringWithoutScheme.removingPercentEncoding ?? link.url
                return AutocompleteResult(text: text, source: .url, url: url,
                                          information: link.title, completingText: query,
                                          score: scores[urlId])
            }.sorted(by: >)
            self.logIntermediate(step: "HistoryTittle", stepShortName: "HT", results: results)
            promise(.success(results))
        }
    }

    private func autocompleteCanCreateNoteResult(for query: String) -> Future<Bool, Error> {
        Future { promise in
            let documentManager = DocumentManager()
            documentManager.loadDocumentByTitle(title: query) { result in
                switch result {
                case .failure(let error):
                    promise(.failure(error))
                case .success(let documentStruct):
                    let canCreateNote = documentStruct == nil && URL(string: query)?.scheme == nil && query.containsCharacters
                    promise(.success(canCreateNote))
                }
            }
        }
    }

    private func autocompleteTopDomainResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            TopDomainDatabase.shared.search(withPrefix: query) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let topDomain):
                    guard let url = URL(string: topDomain.url) else {
                        promise(.failure(TopDomainDatabaseError.notFound))
                        return
                    }
                    let ac = AutocompleteResult(text: url.absoluteString, source: .topDomain, url: url, completingText: query)
                    self.logIntermediate(step: "TopDomain", stepShortName: "TD", results: [ac])
                    promise(.success([ac]))
                }
            }
        }
    }

    private func autocompleteSearchEngineResults(for searchText: String, searchEngine: Autocompleter) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            var promiseReturnedAlready = false

            searchEngine.complete(query: searchText)
                .sink { [weak self] results in
                guard let self = self else { return }
                guard !promiseReturnedAlready else {
                    DispatchQueue.main.async {
                        self.searchEngineArrivedTooLate(results)
                    }
                    return
                }
                promiseReturnedAlready = true
                self.logIntermediate(step: "SearchEngine", stepShortName: "SE", results: results)
                promise(.success(results))
            }.store(in: &self.searchRequestsCancellables)

            let debounceSearchEngineTime = DispatchTime.now().advanced(by: .milliseconds(300))
            DispatchQueue.main.asyncAfter(deadline: debounceSearchEngineTime) {
                guard !promiseReturnedAlready else { return }
                promiseReturnedAlready = true
                promise(.success([]))
            }
        }
    }

    private func searchEngineArrivedTooLate(_ results: [AutocompleteResult]) {
        var finalResults = self.autocompleteResults
        let canCreate = finalResults.firstIndex { $0.source == .createCard } != nil
        let maxGuesses = finalResults.count > 2 ? 4 : 6
        let toInsert = results.prefix(maxGuesses)
        let atIndex = max(0, finalResults.count - (canCreate ? 1 : 0))
        if atIndex < finalResults.count {
            finalResults.insert(contentsOf: toInsert, at: atIndex)
            self.autocompleteResults = finalResults
        }
    }

    // MARK: - Empty Query Suggestions
    private func defaultSuggestionsNotesResults() -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            let documentManager = DocumentManager()
            let limit = 3
            let documentStructs = documentManager.loadAllWithLimit(limit, sortingKey: .updatedAt(false))
            let ids = documentStructs.map { $0.id }
            let scores = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey)
            let autocompleteResults = documentStructs.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), uuid: $0.id, score: scores[$0.id])
            }.sorted(by: >).prefix(limit)
            let autocompleteResultsArray = Array(autocompleteResults)
            self?.logIntermediate(step: "NoteRecents", stepShortName: "NR", results: autocompleteResultsArray)
            promise(.success(autocompleteResultsArray))
        }
    }
}
