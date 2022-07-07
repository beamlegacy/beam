//
//  AutocompleteManager+Publishers.swift
//  Beam
//
//  Created by Remi Santos on 16/07/2021.
//  swiftlint:disable file_length

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
        let mode = self.animatingToMode ?? self.mode
        switch mode {
        case .noteCreation:
            return []
        case .tabGroup(let group):
            return [futureToPublisher(autocompleteTabGroupingResultsInTabGroupMode(for: "", inGroup: group), source: .tabGroup(group: nil))]
        case .general:
            return [
                futureToPublisher(defaultSuggestionsNotesResults(), source: .note),
                futureToPublisher(defaultActionsResults(), source: .action)
            ]
        }
    }

    func getAutocompletePublishers(for searchText: String) -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        if case .tabGroup(let group) = mode {
            return [futureToPublisher(autocompleteTabGroupingResultsInTabGroupMode(for: searchText, inGroup: group), source: .tabGroup(group: nil))]
        }

        let notesPublishers = [
            futureToPublisher(autocompleteNotesResults(for: searchText), source: .note),
            futureToPublisher(autocompleteNotesContentsResults(for: searchText), source: .note),
            getCreateNotePublisher(for: searchText)
        ]

        if case .noteCreation = mode {
            return notesPublishers
        }

        var webPublishers = [
            futureToPublisher(autocompleteTopDomainResults(for: searchText), source: .topDomain),
            futureToPublisher(autocompleteMnemonicResults(for: searchText), source: .mnemonic),
            futureToPublisher(autocompleteHistoryResults(for: searchText), source: .history),
            futureToPublisher(autocompleteLinkStoreResults(for: searchText), source: .url),
            futureToPublisher(autocompleteTabGroupingResults(for: searchText), source: .tabGroup(group: nil))
        ]

        if let state = beamState, !state.isIncognito {
            webPublishers.append(getSearchEnginePublisher(for: searchText, searchEngine: searchEngineCompleter))
        }

        let otherPublishers = [futureToPublisher(autocompleteActionsResults(for: searchText), source: .action)]

        return notesPublishers + webPublishers + otherPublishers
    }

    private func getCreateNotePublisher(for searchText: String) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        autocompleteCanCreateNoteResult(for: searchText)
            .replaceError(with: false)
            .map { [unowned self] canCreate in
                var results = [AutocompleteResult]()
                if canCreate {
                    results.append(Self.DefaultActions.createNoteResult(for: searchText, mode: self.mode, asAction: false))
                }
                return AutocompletePublisherSourceResults(source: .createNote, results: results)
            }.eraseToAnyPublisher()
    }

    func getSearchEnginePublisher(for searchText: String,
                                  searchEngine: SearchEngineAutocompleter) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        futureToPublisher(autocompleteSearchEngineResults(for: searchText, searchEngine: searchEngine), source: .searchEngine).handleEvents(receiveCancel: { [weak searchEngine] in
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

    // MARK: - Notes
    private func autocompleteNotesResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            let start = DispatchTime.now()
            guard let collection = BeamData.shared.currentDocumentCollection else { return promise(.success([])) }
            guard let documents = try? collection.fetch(filters: [.titleMatch(query)]) else { return promise(.success([])) }
            let ids = documents.map { $0.id }
            guard let scores = BeamData.shared.noteLinksAndRefsManager?.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey) else { return promise(.success([])) }
            let autocompleteResults = documents.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: query, uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
            }.sorted(by: >).prefix(6)
            let autocompleteResultsArray = Array(autocompleteResults)
            self?.logIntermediate(step: "NoteTitle", stepShortName: "NT", results: autocompleteResultsArray, startedAt: start)
            promise(.success(autocompleteResultsArray))
        }
    }

    private func _autocompleteNotesResults(for query: String) -> [AutocompleteResult] {
        let start = DispatchTime.now()
        guard let collection = BeamData.shared.currentDocumentCollection else { return [] }
        guard let documents = try? collection.fetch(filters: [.titleMatch(query)]) else { return [] }
        let ids = documents.map { $0.id }
        guard let scores = BeamData.shared.noteLinksAndRefsManager?.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey) else { return [] }
        let autocompleteResults = documents.map {
            AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), completingText: query, uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
        }.sorted(by: >).prefix(6)
        let autocompleteResultsArray = Array(autocompleteResults)
        logIntermediate(step: "NoteTitle", stepShortName: "NT", results: autocompleteResultsArray, startedAt: start)
        return autocompleteResultsArray
    }

    private func autocompleteNotesContentsResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            BeamData.shared.noteLinksAndRefsManager?.search(matchingAllTokensIn: query, maxResults: 10, frecencyParam: AutocompleteManager.noteFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let notesContentResults):
                    let ids = notesContentResults.map { $0.noteId }
                    guard let collection = BeamData.shared.currentDocumentCollection,
                          let docs = try? collection.fetch(filters: [.ids(ids)])
                    else {
                        promise(.failure(BeamDataError.databaseNotFound))
                        return
                    }

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

    // MARK: - URLs
    private func urlStringToDisplay(from url: URL) -> String {
        let result = url.urlStringByRemovingUnnecessaryCharacters
        return result.removingPercentEncoding ?? result
    }

    private func autocompleteHistoryResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            BeamData.shared.urlHistoryManager?.searchLink(query: query, enabledFrecencyParam: AutocompleteManager.urlFrecencyParamKey) { result in
                switch result {
                case .failure(let error): promise(.failure(error))
                case .success(let historyResults):
                    let autocompleteResults = historyResults.map { result -> AutocompleteResult in
                        var information = result.url
                        let url = URL(string: result.url)
                        if let url = url {
                            information = self.urlStringToDisplay(from: url)
                        }

                        var aliasForDestinationURL: URL?
                        if let destinationURLString = result.destinationURL, let destinationURL = URL(string: destinationURLString) {
                            aliasForDestinationURL = destinationURL
                        }
                        let result = AutocompleteResult(text: information, source: .history, url: url,
                                                        aliasForDestinationURL: aliasForDestinationURL,
                                                        information: result.title,
                                                        completingText: query, score: result.frecencySortScore, urlFields: [.text])
                        if let searchEngineResult = self.convertResultToSearchEngineResultIfNeeded(result) {
                            return searchEngineResult
                        }
                        return result
                    }
                    self.logIntermediate(step: "HistoryContent", stepShortName: "HC", results: autocompleteResults, startedAt: start)
                    promise(.success(autocompleteResults))
                }
            }

        }
    }

    private func autocompleteLinkStoreResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            guard let scoredLinks = BeamData.shared.urlHistoryManager?.getTopScoredLinks(matchingUrl: query, frecencyParam: AutocompleteManager.urlFrecencyParamKey, limit: 6) else {
                promise(.failure(BeamDataError.databaseNotFound))
                return
            }
            let results = scoredLinks.map { (scoredLink) -> AutocompleteResult in
                let url = URL(string: scoredLink.url)
                var text = ""
                if let url = url {
                    text = self.urlStringToDisplay(from: url)
                }
                let info = scoredLink.title?.isEmpty == false ? scoredLink.title : nil
                var aliasForDestinationURL: URL?
                if let destinationURLString = scoredLink.destinationURL, let destinationURL = URL(string: destinationURLString) {
                    aliasForDestinationURL = destinationURL
                }
                let result = AutocompleteResult(text: text, source: .url, url: url,
                                                aliasForDestinationURL: aliasForDestinationURL,
                                                information: info, completingText: query,
                                                score: scoredLink.frecencySortScore, urlFields: .text)
                if let searchEngineResult = self.convertResultToSearchEngineResultIfNeeded(result) {
                    return searchEngineResult
                }
                return result
            }.sorted(by: >)
            self.logIntermediate(step: "HistoryTitle", stepShortName: "HT", results: results, startedAt: start)
            promise(.success(results))
        }
    }

    private func autocompleteCanCreateNoteResult(for query: String) -> Future<Bool, Error> {
        Future { promise in
            guard let collection = BeamData.shared.currentDocumentCollection else { promise(.failure(BeamDataError.databaseNotFound))
                return
            }
            let document = try? collection.fetchFirst(filters: [.title(query)])
            let canCreateNote = document == nil && URL(string: query)?.scheme == nil && query.containsCharacters
            promise(.success(canCreateNote))
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
                    if let link = LinkStore.shared.getLinks(matchingUrl: url.urlWithScheme.absoluteString).values.first,
                       let title = link.title, !title.isEmpty {
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
            guard let url = BeamData.shared.mnemonicManager?.getMnemonic(text: query) else {
                promise(.failure(TopDomainDatabaseError.notFound))
                return
            }

            let text = url.absoluteString
            var information: String?
            let linkId = LinkStore.shared.getOrCreateId(for: url.urlWithScheme.absoluteString, title: nil)
            if let link = LinkStore.shared.linkFor(id: linkId),
               let title = link.title {
                information = title
            }
            let ac = AutocompleteResult(text: text, source: .mnemonic, url: url, information: information, completingText: query, urlFields: .text)
            self.logIntermediate(step: "Mnemonic", stepShortName: "MN", results: [ac], startedAt: start)
            promise(.success([ac]))
        }
    }

    // MARK: - Search Engine
    private func autocompleteSearchEngineResults(for searchText: String, searchEngine: SearchEngineAutocompleter) -> Future<[AutocompleteResult], Error> {
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
        self.setAutocompleteResults(insertSearchEngineResults(results, in: autocompleteResults))
    }

    // MARK: - Tab Grouping
    private func autocompleteTabGroupingResultsInTabGroupMode(for query: String, inGroup group: TabGroup) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            var results = [AutocompleteResult]()
            let links = LinkStore.shared.getLinks(for: group.pageIds)
            if query.isEmpty {
                results.append(
                    AutocompleteResult(text: loc("Open All Tabs"), source: .action, customIcon: "field-web", score: .greatestFiniteMagnitude,
                                       handler: { beamState in
                                           beamState.openTabGroup(group)
                                       })
                )
            }

            let queryLowercase = query.lowercased()
            results.append(contentsOf: links.compactMap({ (_, link) in
                guard query.isEmpty || link.title?.lowercased().contains(queryLowercase) == true || link.url.contains(queryLowercase) else {
                    return nil
                }

                let hasTitle = link.title?.isEmpty == false
                let title = link.title ?? ""
                let url = URL(string: link.url)
                let urlString = url?.urlStringByRemovingUnnecessaryCharacters ?? link.url
                return AutocompleteResult(text: hasTitle ? title : urlString, source: .url, url: url,
                                          information: hasTitle ? urlString : nil, completingText: query,
                                          uuid: link.id, score: link.frecencyVisitSortScore, urlFields: hasTitle ? .info : .text,
                                          handler: { state in
                    guard let url = url else { return }
                    state.createTab(withURLRequest: URLRequest(url: url))
                })
            }))

            self.logIntermediate(step: "TabGroupingInMode", stepShortName: "TG", results: results, startedAt: start)

            promise(.success(results))
        }
    }

    private func autocompleteTabGroupingResults(for query: String) -> Future<[AutocompleteResult], Error> {
        Future { promise in
            let start = DispatchTime.now()
            var results = [AutocompleteResult]()
            if let group = BeamData.shared.tabGroupingDBManager?.searchGroups(forText: query).first {
                let scores = LinkStore.shared.getLinks(for: group.pageIds).compactMap { $1.frecencyVisitSortScore }
                let bestScore = scores.max()
                results.append(AutocompleteResult(text: group.title ?? "Tab Group (\(group.pageIds.count) tabs)",
                                                  source: .tabGroup(group: group), completingText: query, uuid: group.id, score: bestScore, handler: { state in
                    state.autocompleteManager.animateToMode(.tabGroup(group: group), updateResults: true)
                }))
            }
            self.logIntermediate(step: "TabGrouping", stepShortName: "TG", results: results, startedAt: start)

            promise(.success(results))
        }
    }

    // MARK: - Actions Suggestions
    private func defaultSuggestionsNotesResults() -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            guard let beamState = self?.beamState, !beamState.omniboxInfo.wasFocusedFromTab else {
                promise(.success([]))
                return
            }
            let start = DispatchTime.now()
            let limit = 3
            let currentNoteID = beamState.mode == .note ? beamState.currentNote?.id : nil
            let recentsNotes = beamState.recentsManager.recentNotes.filter { $0.id != currentNoteID }
            let ids = recentsNotes.map { $0.id }
            guard let scores = BeamData.shared.noteLinksAndRefsManager?.getFrecencyScoreValues(noteIds: ids, paramKey: AutocompleteManager.noteFrecencyParamKey) else {
                promise(.failure(BeamDataError.databaseNotFound))
                return
            }
            let autocompleteResults = recentsNotes.map {
                AutocompleteResult(text: $0.title, source: .note(noteId: $0.id), uuid: $0.id, score: scores[$0.id]?.frecencySortScore)
            }.sorted(by: >).prefix(limit)
            let autocompleteResultsArray = Array(autocompleteResults)
            self?.logIntermediate(step: "NoteRecents", stepShortName: "NR", results: autocompleteResultsArray, startedAt: start)
            promise(.success(autocompleteResultsArray))
        }
    }

    private func autocompleteActionsResults(for searchText: String) -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            guard let self = self, let state = self.beamState, !state.omniboxInfo.wasFocusedFromTab else {
                promise(.success([]))
                return
            }
            let searchableActions: [AutocompleteResult] = [
                Self.DefaultActions.createNoteResult(for: nil, mode: self.mode, asAction: true, completingText: searchText)
            ]
            let match = searchText.lowercased()
            let results = searchableActions.filter { r in
                let lowercasedText = r.text.lowercased()
                if lowercasedText.hasPrefix(match) {
                    return true
                }
                var words = lowercasedText.wordRanges.map { r.text[$0] }
                if let additionalSearchTerms = r.additionalSearchTerms {
                    words += additionalSearchTerms.map { Substring($0) }
                }
                return words.contains { $0.lowercased().hasPrefix(match) }
            }
            promise(.success(results))
        }
    }

    private func defaultActionsResults() -> Future<[AutocompleteResult], Error> {
        Future { [weak self] promise in
            guard let self = self, let state = self.beamState, !state.omniboxInfo.wasFocusedFromTab else {
                promise(.success([]))
                return
            }
            var actions = [AutocompleteResult]()
            let mode = state.mode
            let isFocusingTab = state.omniboxInfo.wasFocusedFromTab
            if mode == .web {
                actions.append(contentsOf: [
                    Self.DefaultActions.journalAction,
                    Self.DefaultActions.allNotesAction,
                    Self.DefaultActions.switchToNotesAction
                ])
            } else {
                if mode != .today {
                    actions.append(Self.DefaultActions.journalAction)
                }
                if state.mode != .page || state.currentPage?.id != .allNotes {
                    actions.append(Self.DefaultActions.allNotesAction)
                }
                if state.hasBrowserTabs {
                    actions.append(Self.DefaultActions.switchToWebAction)
                }
            }
            if !isFocusingTab {
                actions.append(Self.DefaultActions.createNoteResult(for: nil, mode: self.mode, asAction: false))
            }
            promise(.success(actions))
        }
    }

    // MARK: - Helpers
    private func convertResultToSearchEngineResultIfNeeded(_ result: AutocompleteResult) -> AutocompleteResult? {
        guard let url = result.url,
              let searchEngine = searchEngine.canHandle(url) ? searchEngine : SearchEngineProvider.provider(for: url)?.searchEngine
        else { return nil }
        var text = result.text
        var information: String?
        if let query = searchEngine.queryFromURL(url) {
            text = query
            information = searchEngine.description
        }
        guard !text.isEmpty else { return nil }
        return AutocompleteResult(text: text, source: .searchEngine, url: url, information: information,
                                  completingText: result.completingText, score: result.score, urlFields: [])
    }
}
