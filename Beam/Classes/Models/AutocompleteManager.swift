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

    private let searchEngineCompleter = Autocompleter()
    private var autocompleteSearchGuessesHandler: (([AutocompleteResult]) -> Void)?
    private var autocompleteTimeoutBlock: DispatchWorkItem?
    private let beamData: BeamData
    private var scope = Set<AnyCancellable>()

    init(with data: BeamData) {
        self.beamData = data

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

    private func autocompleteNotesResults(for query: String) -> [AutocompleteResult] {
        return beamData.documentManager.documentsWithLimitTitleMatch(title: query, limit: 6)
            // Eventually, we should not show notes under a certain score threshold
            // Disabling it for now until we have a better scoring system
            .map { AutocompleteResult(text: $0.title, source: .note, completingText: query, uuid: $0.id) }
    }

    private func autocompleteNotesContentsResults(for query: String, excludingNotes: [AutocompleteResult]) -> [AutocompleteResult] {
        var resultsToExclude = excludingNotes
        let searchResults = GRDBDatabase.shared.search(matchingAllTokensIn: query, maxResults: 10)
        return searchResults.compactMap { result -> AutocompleteResult? in
            guard !resultsToExclude.contains(where: { $0.text == result.title || $0.uuid.uuidString == result.uid }) else {
                return nil
            }
            guard beamData.documentManager.loadDocumentByTitle(title: result.title) != nil else { return nil }
            let autocompleteResult = AutocompleteResult(text: result.title,
                                                        source: .note,
                                                        completingText: query,
                                                        uuid: UUID(uuidString: result.uid) ?? UUID())
            resultsToExclude.append(autocompleteResult)
            return autocompleteResult
        }
    }

    private func autocompleteHistoryResults(for query: String) -> [AutocompleteResult] {
        GRDBDatabase.shared.searchHistory(query: query).map {
            var urlString = $0.url
            let url = URL(string: urlString)
            if let url = url {
                urlString = url.urlStringWithoutScheme
            }
            return AutocompleteResult(text: $0.title, source: .history, url: url, information: urlString, completingText: query)
        }
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
            self.cancelAutocomplete()
            return
        }

        var finalResults = [AutocompleteResult]()

        // #1 Existing Notes
        var notesNamesResults = autocompleteNotesResults(for: searchText)
        // #2 Notes contents
        let notesContentsResults = autocompleteNotesContentsResults(for: searchText, excludingNotes: notesNamesResults)
        notesNamesResults.append(contentsOf: notesContentsResults)
        // #3 History results
        let historyResults = autocompleteHistoryResults(for: searchText)

        finalResults = sortResults(notesResults: notesNamesResults, historyResults: historyResults)

        // #5 Create Card
        let canCreateNote = beamData.documentManager.loadDocumentByTitle(title: searchText) == nil && URL(string: searchText)?.scheme == nil
        if canCreateNote {
            // if the card doesn't exist, propose to create it
            finalResults.append(AutocompleteResult(text: searchText, source: .createCard, information: "New card", completingText: searchText))
        }

        guard searchText.count > 1 else {
            autocompleteSearchGuessesHandler = nil
            self.autocompleteResults = finalResults
            return
        }

        // #4 Search Engine Autocomplete results
        debouncedSearchEngineResults(for: searchText,
                                     currentResults: finalResults,
                                     allowCreateNote: canCreateNote,
                                     onUpdateResultsBlock: isRemovingCharacters ? nil : { [weak self] results in
                                        guard let self = self else { return }
                                        // #6 Select the first result if compatible
                                        self.automaticallySelectFirstResultIfNeeded(withResults: results, searchText: searchText)
                                     })
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
            } else {
                self.autocompleteResults.insert(contentsOf: toInsert, at: atIndex)
            }
        }
        self.searchEngineCompleter.complete(query: searchText)

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
            self.autocompleteSelectedIndex = 0
        } else if self.autocompleteSelectedIndex == 0 {
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
        autocompleteResults = []
        autocompleteTimeoutBlock?.cancel()
    }

    func resetQuery() {
        searchQuery = ""
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
            self.animateInputingCharacter = true
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
              let selectedRange = self.searchQuerySelectedRange,
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
