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
    struct AutocompletePublisherSourceResults: Identifiable {
        var id = UUID()
        var source: AutocompleteResult.Source
        var results: [AutocompleteResult]
    }

    private func logIntermediate(step: String, stepShortName: String, results: [AutocompleteResult], startedAt: DispatchTime) {
        Self.logIntermediate(step: step, stepShortName: stepShortName, results: results, startedAt: startedAt)
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
            futureToPublisher(autocompleteMnemonicResults(for: searchText), source: .mnemonic),
            futureToPublisher(autocompleteHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteAliasHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteLinkStoreResults(for: searchText), source: .url),
            self.autocompleteCanCreateNoteResult(for: searchText)
                .replaceError(with: false)
                .map { canCreate in
                    let createResult = AutocompleteResult(text: searchText,
                                                          source: .createCard,
                                                          information: "New note",
                                                          completingText: searchText)
                    let results = canCreate ? [createResult] : []
                    return AutocompletePublisherSourceResults(source: AutocompleteResult.Source.createCard, results: results)
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
                return AutocompletePublisherSourceResults(source: source, results: someResults)
            }
            .eraseToAnyPublisher()
    }

    private func autocompleteNotesResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            let start = DispatchTime.now()
            let documentManager = DocumentManager()
            documentManager.documentsWithTitleMatch(title: query) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let documentStructs):
                    let ids = documentStructs.map { $0.id }
                    let scores = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey)
                    let autocompleteResults = documentStructs.map {
                        AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: query, uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
                    }.sorted(by: >).prefix(6)
                    let autocompleteResultsArray = Array(autocompleteResults)
                    self?.logIntermediate(step: "NoteTitle", stepShortName: "NT", results: autocompleteResultsArray, startedAt: start)
                    promise(.success(autocompleteResultsArray))
                }
            }
        }
    }

    private func autocompleteNotesContentsResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
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
                    self.logIntermediate(step: "NoteContent", stepShortName: "NC", results: autocompleteResults, startedAt: start)
                    promise(.success(autocompleteResults))
                }
            }
        }
    }

    private func autocompleteHistoryResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            GRDBDatabase.shared.searchLink(query: query, enabledFrecencyParam: AutocompleteManager.urlFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let historyResults):
                    let autocompleteResults = historyResults.map { result -> AutocompleteResult in
                        var information = result.url
                        let url = URL(string: result.url)
                        if let url = url {
                            information = url.urlStringWithoutScheme.removingPercentEncoding ?? url.urlStringWithoutScheme
                        }
                        return AutocompleteResult(text: information, source: .history,
                                                  url: url, information: result.title, completingText: query, score: result.frecency?.frecencySortScore, urlFields: [.text])
                    }
                    self.logIntermediate(step: "HistoryContent", stepShortName: "HC", results: autocompleteResults, startedAt: start)
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
                case .success(let linkResult):
                    guard let linkResult = linkResult else {
                        promise(.success([]))
                        return
                    }
                    var information = linkResult.url
                    let url = URL(string: linkResult.url)
                    if let url = url {
                        information = url.urlStringWithoutScheme.removingPercentEncoding ?? url.urlStringWithoutScheme
                    }
                    promise(.success([AutocompleteResult(text: information,
                                                         source: .history,
                                                         url: url,
                                                         information: linkResult.title,
                                                         completingText: query,
                                                         score: linkResult.frecency?.frecencySortScore, urlFields: [.text])
                                     ]))
                }
            }
        }
    }

    private func autocompleteLinkStoreResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            let scoredLinks = GRDBDatabase.shared.getTopScoredLinks(matchingUrl: query, frecencyParam: AutocompleteManager.urlFrecencyParamKey, limit: 6)
            let results = scoredLinks.map { (scoredLink) -> AutocompleteResult in
                let url = URL(string: scoredLink.link.url)
                let text = url?.urlStringWithoutScheme.removingPercentEncoding ?? URL(string: scoredLink.link.url)?.urlStringWithoutScheme.removingPercentEncoding ?? ""
                return AutocompleteResult(text: text, source: .url, url: url,
                                          information: scoredLink.link.title, completingText: query,
                                          score: scoredLink.frecency?.frecencySortScore, urlFields: .text)
            }.sorted(by: >)
            self.logIntermediate(step: "HistoryTitle", stepShortName: "HT", results: results, startedAt: start)
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
            let start = DispatchTime.now()
            TopDomainDatabase.shared.search(withPrefix: query) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let topDomain):
                    guard let url = URL(string: topDomain.url) else {
                        promise(.failure(TopDomainDatabaseError.notFound))
                        return
                    }

                    let text = url.absoluteString
                    var information: String?
                    let linkId = LinkStore.shared.getOrCreateIdFor(url: url.urlWithScheme.absoluteString, title: nil)
                    if let link = LinkStore.shared.linkFor(id: linkId),
                       let title = link.title {
                        information = title
                    }
                    let ac = AutocompleteResult(text: text, source: .topDomain, url: url, information: information, completingText: query, urlFields: .text)
                    self.logIntermediate(step: "TopDomain", stepShortName: "TD", results: [ac], startedAt: start)
                    promise(.success([ac]))
                }
            }
        }
    }

    // Mnemonics are disabled for now. It is an experiment on how to find shortcuts for recently visited sites, but in the end the new scoring system seems to be good enough for most cases. I will rework it to use it as a score booster that enables taking over the omnibox when there is no url prefix takeover. For example when you always visit the merge request page, an often type "merg..." and would like that to directly take you to the correct web page even though the URL starts with gitlab instead of merge. More work to be done on that later. https://linear.app/beamapp/issue/BE-3010/reworke-the-mnemonic-system-in-the-omnibox
    static let enableMmnemonics = false
    private func autocompleteMnemonicResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            guard Self.enableMmnemonics else { return promise(.success([])) }
            let start = DispatchTime.now()
            guard let url = GRDBDatabase.shared.getMnemonic(text: query) else {
                promise(.failure(TopDomainDatabaseError.notFound))
                return
            }

            let text = url.absoluteString
            var information: String?
            let linkId = LinkStore.shared.getOrCreateIdFor(url: url.urlWithScheme.absoluteString, title: nil)
            if let link = LinkStore.shared.linkFor(id: linkId),
               let title = link.title {
                information = title
            }
            let ac = AutocompleteResult(text: text, source: .mnemonic, url: url, information: information, completingText: query, urlFields: .text)
            self.logIntermediate(step: "Mnemonic", stepShortName: "MN", results: [ac], startedAt: start)
            promise(.success([ac]))
        }
    }

    private func autocompleteSearchEngineResults(for searchText: String, searchEngine: Autocompleter) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
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
                    self.logIntermediate(step: "SearchEngine", stepShortName: "SE", results: results, startedAt: start)
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
            let start = DispatchTime.now()
            let documentManager = DocumentManager()
            let limit = 3
            let documentStructs = documentManager.loadAllWithLimit(limit, sortingKey: .updatedAt(false))
            let ids = documentStructs.map { $0.id }
            let scores = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey)
            let autocompleteResults = documentStructs.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
            }.sorted(by: >).prefix(limit)
            let autocompleteResultsArray = Array(autocompleteResults)
            self?.logIntermediate(step: "NoteRecents", stepShortName: "NR", results: autocompleteResultsArray, startedAt: start)
            promise(.success(autocompleteResultsArray))
        }
    }
}

// MARK: - Quickly mock results for debugging
#if DEBUG
extension AutocompleteManager {

    private func mockResultsPublisher(_ results: [AutocompleteResult]) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            promise(.success(results))
        }
    }

    func getMockAutocompletePublishers(for searchText: String) -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        if searchText.count == 1 {
            return [
                futureToPublisher(mockResultsPublisher([
                    .init(text: "netflix.com", source: .topDomain, url: URL(string: "netflix.com")!, completingText: searchText, urlFields: .text)
                ]), source: .topDomain)
            ]
        } else {
            return [
                futureToPublisher(mockResultsPublisher([
                    .init(text: "eloquentjavascript.net", source: .url, url: URL(string: "https://eloquentjavascript.net")!, information: "Eloquent Javascript", completingText: searchText, score: 190, urlFields: .text),
                    .init(text: "eloquentjavascript.net/test", source: .url, url: URL(string: "https://eloquentjavascript.net/test")!, information: "Other Javascript", completingText: searchText, score: 110, urlFields: .text)
                ]), source: .url)
            ]
        }
    }
}

#endif
