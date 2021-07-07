//
//  AutocompleteManager.swift
//  Beam
//
//  Created by Remi Santos on 29/03/2021.
//

import Foundation
import Combine
import BeamCore
import SwiftUI

// BeamState Autocomplete management
class AutocompleteManager: ObservableObject {

    @Published var searchQuery: String = ""

    private var textChangeIsFromSelection = false
    private var replacedProposedText: String?

    @Published var searchQuerySelectedRange: Range<Int>?
    @Published var autocompleteResults = [AutocompleteResult]()
    @Published var autocompleteSelectedIndex: Int? = nil {
        didSet {
            updateSearchQueryWhenSelectingAutocomplete(autocompleteSelectedIndex, previousSelectedIndex: oldValue)
        }
    }

    @Published var animateInputingCharacter = false

    private let searchEngineCompleter: Autocompleter
    private var autocompleteSearchGuessesHandler: (([AutocompleteResult]) -> Void)?
    private var autocompleteTimeoutBlock: DispatchWorkItem?
    private let beamData: BeamData
    private var scope = Set<AnyCancellable>()

    init(with data: BeamData, searchEngine: SearchEngine) {
        beamData = data
        searchEngineCompleter = Autocompleter(searchEngine: searchEngine)

        $searchQuery
            .dropFirst()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.buildAutocompleteResults(for: query)
            }.store(in: &scope)

        searchEngineCompleter.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self, let guessesHandler = self.autocompleteSearchGuessesHandler else { return }
            guessesHandler(results)
        }.store(in: &scope)
    }

    private func autocompleteNotesResults(for query: String,
                                          completion: @escaping (Swift.Result<[AutocompleteResult], Error>) -> Void) {
        beamData.documentManager.documentsWithLimitTitleMatch(title: query, limit: 6) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let documentStructs):
                let autocompleteResults = documentStructs.map {
                    AutocompleteResult(text: $0.title, source: .note, completingText: query, uuid: $0.id)
                }
                completion(.success(autocompleteResults))
            }
        }
    }

    private func autocompleteNotesContentsResults(for query: String,
                                                  completion: @escaping (Swift.Result<[AutocompleteResult], Error>) -> Void) {
        GRDBDatabase.shared.search(matchingAllTokensIn: query, maxResults: 10) { [weak beamData] result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let notesContentResults):
                // TODO: get all titles and make a single CoreData request for all titles
                let autocompleteResults = notesContentResults.compactMap { result -> AutocompleteResult? in
                    // Check if the note still exists before proceeding.
                    guard beamData?.documentManager.loadDocumentById(id: result.noteId) != nil else { return nil }
                    return AutocompleteResult(text: result.title,
                                              source: .note,
                                              completingText: query,
                                              uuid: result.uid)
                }

                completion(.success(autocompleteResults))
            }
        }
    }

    private func autocompleteHistoryResults(for query: String,
                                            completion: @escaping (Swift.Result<[AutocompleteResult], Error>) -> Void) {
        GRDBDatabase.shared.searchHistory(query: query, enabledFrecencyParam: .readingTime30d0) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let historyResults):
                let autocompleteResults = historyResults.map { result -> AutocompleteResult in
                    var urlString = result.url
                    let url = URL(string: urlString)
                    if let url = url {
                        urlString = url.urlStringWithoutScheme
                    }
                    return AutocompleteResult(text: result.title, source: .history, url: url, information: urlString, completingText: query)
                }
                completion(.success(autocompleteResults))
            }
        }
    }

    private func autocompleteResultsUnique(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        var seenText = Set<String>()
        var seenUUID = Set<UUID>()

        return sequence.filter { seenText.update(with: $0.text) == nil && seenUUID.update(with: $0.uuid) == nil }
    }

    private func getSelectedText(for text: String) -> String? {
        guard let range = searchQuerySelectedRange,
              range.startIndex > 0,
              range.endIndex <= text.count else { return nil }
        return text.substring(range: range)
    }

    private func getUnselectedText(for text: String) -> String? {
        guard let range = searchQuerySelectedRange,
              range.startIndex > 0,
              range.startIndex <= text.count else { return nil }
        return text.substring(from: 0, to: range.startIndex)
    }

    private func buildAutocompleteResults(for receivedQueryString: String) {
        // Track the elasped time to build autocomplete results
        let startChrono = DispatchTime.now()

        guard !textChangeIsFromSelection else {
            textChangeIsFromSelection = false
            return
        }
        var searchText = receivedQueryString
        let previousUnselectedText = getUnselectedText(for: searchQuery)?.lowercased() ?? searchQuery
        let isRemovingCharacters = searchText.count < previousUnselectedText.count || searchText.lowercased() == previousUnselectedText

        if let realText = replacedProposedText {
            searchText = realText
            replacedProposedText = nil
        } else {
            self.resetAutocompleteSelection()
        }

        guard !searchText.isEmpty else {
            cancelAutocomplete()
            return
        }

        let queue = DispatchQueue.global(qos: .userInteractive)
        queue.async {
            var autocompleteResults = [AutocompleteResult.Source: [AutocompleteResult]]()
            let group = DispatchGroup()
            let mergeQueue = DispatchQueue(label: "autocomplete.result.merge")

            group.enter()
            self.autocompleteNotesResults(for: searchText) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                    group.leave()
                case .success(let acResults):
                    mergeQueue.async {
                        autocompleteResults[.note, default: []].append(contentsOf: acResults)
                        group.leave()
                    }
                }
            }

            group.enter()
            self.autocompleteNotesContentsResults(for: searchText) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                    group.leave()
                case .success(let acResults):
                    mergeQueue.async {
                        autocompleteResults[.note, default: []].append(contentsOf: acResults)
                        group.leave()
                    }
                }
            }

            group.enter()
            self.autocompleteHistoryResults(for: searchText) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                    group.leave()
                case .success(let acResults):
                    mergeQueue.async {
                        autocompleteResults[.history, default: []].append(contentsOf: acResults)
                        group.leave()
                    }
                }
            }

            var canCreateNote = false

            group.enter()
            self.beamData.documentManager.loadDocumentByTitle(title: searchText) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .autocompleteManager)
                    group.leave()
                case .success(let documentStruct):
                    mergeQueue.async {
                        canCreateNote = documentStruct == nil && URL(string: searchText)?.scheme == nil
                        group.leave()
                    }
                }
            }

            group.wait()

            if let noteResults = autocompleteResults[.note] {
                autocompleteResults[.note] = self.autocompleteResultsUnique(sequence: noteResults)
            }

            var finalResults = self.sortResults(notesResults: autocompleteResults[.note, default: []],
                                                historyResults: autocompleteResults[.history, default: []])

            if canCreateNote {
                // if the card doesn't exist, propose to create it
                finalResults.append(AutocompleteResult(text: searchText,
                                                       source: .createCard,
                                                       information: "New card",
                                                       completingText: searchText))
            }

            if !finalResults.isEmpty {
                Logger.shared.logDebug("-- Autosuggest results for `\(searchText)` --", category: .autocompleteManager)
                for result in finalResults {
                    Logger.shared.logDebug("\(result.source) \(result.id) \(String(describing: result.url))", category: .autocompleteManager)
                }
            }

            let (elapsedTime, timeUnit) = startChrono.endChrono()
            Logger.shared.logInfo("autocomplete results in \(elapsedTime) \(timeUnit)", category: .autocompleteManager)

            guard searchText.count > 1 else {
                DispatchQueue.main.async {
                    self.autocompleteSearchGuessesHandler = nil
                    self.autocompleteResults = finalResults
                }
                return
            }

            self.debouncedSearchEngineResults(for: searchText,
                                              currentResults: finalResults,
                                              allowCreateNote: canCreateNote,
                                              onUpdateResultsBlock: isRemovingCharacters ? nil : { [weak self] results in
                                                guard let self = self else { return }
                                                // #6 Select the first result if compatible
                                                self.automaticallySelectFirstResultIfNeeded(withResults: results, searchText: searchText)
                                              })
        }
    }

    private func debouncedSearchEngineResults(for searchText: String,
                                              currentResults: [AutocompleteResult],
                                              allowCreateNote: Bool,
                                              onUpdateResultsBlock: (([AutocompleteResult]) -> Void)?) {
        autocompleteSearchGuessesHandler = { [weak self] results in
            guard let self = self else { return }
            var newResults = currentResults
            let maxGuesses = newResults.count > 2 ? 4 : 6
            let toInsert = results.prefix(maxGuesses)
            let atIndex = newResults.count - (allowCreateNote ? 1 : 0)
            self.autocompleteTimeoutBlock?.cancel()
            if self.autocompleteTimeoutBlock != nil {
                newResults.insert(contentsOf: toInsert, at: atIndex)
                self.autocompleteResults = newResults
                onUpdateResultsBlock?(newResults)
            } else if atIndex < self.autocompleteResults.count {
                self.autocompleteResults.insert(contentsOf: toInsert, at: atIndex)
            }
        }
        searchEngineCompleter.complete(query: searchText)

        // Delay setting the results, so we give some time for search engine
        // Preventing the UI to blink
        autocompleteTimeoutBlock?.cancel()
        autocompleteTimeoutBlock = DispatchWorkItem(block: {
            self.autocompleteTimeoutBlock = nil
            self.autocompleteResults = currentResults
            onUpdateResultsBlock?(currentResults)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: autocompleteTimeoutBlock!)
    }

    private func isResultCandidateForAutoselection(_ result: AutocompleteResult, forSearch searchText: String) -> Bool {
        return result.source == .history && result.text.lowercased().starts(with: searchText.lowercased())
    }

    private func automaticallySelectFirstResultIfNeeded(withResults results: [AutocompleteResult], searchText: String) {
        if let firstResult = results.first, isResultCandidateForAutoselection(firstResult, forSearch: searchText) {
            autocompleteSelectedIndex = 0
        } else if autocompleteSelectedIndex == 0 {
            // first result was selected but is not matching anymore
            self.resetAutocompleteSelection(resetText: true)
        }
    }

    private func sortResults(notesResults: [AutocompleteResult], historyResults: [AutocompleteResult]) -> [AutocompleteResult] {
        // this logic should eventually become smarter to always include the right amount of result per source.

        var results = [AutocompleteResult]()

        let maxHistoryResults = notesResults.isEmpty ? 6 : 4
        let historyResultsTruncated = Array(historyResults.prefix(maxHistoryResults))

        let maxNotesSuggestions = historyResults.isEmpty ? 6 : 4
        let notesResultsTruncated = Array(notesResults.prefix(maxNotesSuggestions))

        results.append(contentsOf: notesResultsTruncated)
        results.append(contentsOf: historyResultsTruncated)

        return results
    }

    private func updateSearchQueryWhenSelectingAutocomplete(_ selectedIndex: Int?, previousSelectedIndex: Int?) {
        if let i = autocompleteSelectedIndex, i >= 0, i < autocompleteResults.count {
            let result = autocompleteResults[i]
            let resultText = result.text
            textChangeIsFromSelection = true

            // if the first result is compatible with autoselection, select the added string
            if i == 0, let completingText = result.completingText,
               isResultCandidateForAutoselection(result, forSearch: completingText) {
                let newSelection = completingText.wholeRange.upperBound..<resultText.count
                searchQuery = completingText + resultText.substring(range: newSelection)
                searchQuerySelectedRange = newSelection
            } else {
                searchQuery = resultText
                searchQuerySelectedRange = resultText.count..<resultText.count
            }
        }
    }

    private func resetAutocompleteSelection(resetText: Bool) {
        if resetText, let currentSelectedIndex = autocompleteSelectedIndex,
           currentSelectedIndex < autocompleteResults.count {
            let previousResult = autocompleteResults[currentSelectedIndex]
            setQueryWithoutAutocompleting(previousResult.completingText ?? "")
        }
        searchQuerySelectedRange = nil
        autocompleteSelectedIndex = nil
    }
}

// MARK: - Public methods
extension AutocompleteManager {

    func selectPreviousAutocomplete() {
        if let i = autocompleteSelectedIndex {
            let newIndex = i - 1
            if newIndex >= 0 {
                autocompleteSelectedIndex = newIndex
            } else {
                resetAutocompleteSelection(resetText: true)
            }
        } else {
            autocompleteSelectedIndex = (-1).clampInLoop(0, autocompleteResults.count - 1)
        }
    }

    func selectNextAutocomplete() {
        if let i = autocompleteSelectedIndex {
            autocompleteSelectedIndex = (i + 1).clampInLoop(0, autocompleteResults.count - 1)
        } else {
            autocompleteSelectedIndex = 0
        }
    }

    func resetAutocompleteSelection() {
        resetAutocompleteSelection(resetText: false)
    }

    func cancelAutocomplete() {
        resetAutocompleteSelection()
        searchEngineCompleter.clear()
        autocompleteResults = []
        autocompleteTimeoutBlock?.cancel()
    }

    func resetQuery() {
        searchQuery = ""
        searchEngineCompleter.clear()
        autocompleteResults = []
        autocompleteTimeoutBlock?.cancel()
    }

    func setQueryWithoutAutocompleting(_ query: String) {
        textChangeIsFromSelection = true
        searchQuery = query
    }

    func shakeOmniBox() {
        let animation = Animation.interpolatingSpring(stiffness: 500, damping: 16)
        withAnimation(animation) {
            animateInputingCharacter = true
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(150))) { [weak self] in
            withAnimation(animation) {
                self?.animateInputingCharacter = false
            }
        }
    }

    // Allows the user to enter the next character of the suggestion
    // while keeping the same visual state
    func replacementTextForProposedText(_ proposedText: String) -> (String, Range<Int>)? {
        let currentText = searchQuery

        guard let selectedText = getSelectedText(for: currentText),
              let selectedRange = searchQuerySelectedRange,
              !selectedRange.isEmpty else { return nil }

        var unselectedProposedText = proposedText
        if proposedText.count > selectedRange.endIndex {
            // Edge case, depending on typing speed, the proposedText might have the new character after the selected text.
            unselectedProposedText.removeSubrange(proposedText.index(at: selectedRange.startIndex)..<proposedText.index(at: selectedRange.endIndex))
        }

        // if new entered character is the next character in selection, user is following the autocompletion
        guard currentText.lowercased().starts(with: unselectedProposedText.lowercased()),
              unselectedProposedText.last?.lowercased() == selectedText.first?.lowercased()
        else { return nil }

        replacedProposedText = unselectedProposedText
        let newRange = unselectedProposedText.count..<currentText.count
        searchQuerySelectedRange = unselectedProposedText.count..<currentText.count
        let newText = unselectedProposedText + currentText.substring(range: newRange)
        return (newText, newRange)
    }
}
