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
    @Published var animatedQuery: String?
    let beamData: BeamData

    private let searchEngineCompleter: Autocompleter
    private var searchEngineResultHandler: (([AutocompleteResult]) -> Void)?
    private var searchEngineTimeoutBlock: DispatchWorkItem?
    private var scope = Set<AnyCancellable>()
    private var searchRequestsCancellables = Set<AnyCancellable>()

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
            guard let self = self, let guessesHandler = self.searchEngineResultHandler else { return }
            guessesHandler(results)
        }.store(in: &scope)
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

    typealias AutocompleteSourceResult = [AutocompleteResult.Source: [AutocompleteResult]]

    private func buildAutocompleteResults(for receivedQueryString: String) {

        guard !textChangeIsFromSelection else {
            textChangeIsFromSelection = false
            return
        }
        let startChrono = DispatchTime.now()

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

        stopCurrentCompletionWork()
        let publishers = self.getAutocompletePublishers(for: searchText)
        Publishers.MergeMany(publishers).collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] publishersResults in
                guard let self = self else { return }
                let (finalResults, canCreateNote) = self.mergeAndSortPublishersResults(publishersResults: publishersResults, for: searchText)
                self.logAutocompleteResultFinished(for: searchText, finalResults: finalResults, startedAt: startChrono)

                let onUpdateResultsBlock: (([AutocompleteResult]) -> Void)? = isRemovingCharacters ? nil : { [weak self] results in
                    guard let self = self else { return }
                    self.automaticallySelectFirstResultIfNeeded(withResults: results, searchText: searchText)
                }
                guard searchText.count > 1 else {
                    self.autocompleteResults = finalResults
                    onUpdateResultsBlock?(finalResults)
                    return
                }

                let insertIndex = max(0, finalResults.count - (canCreateNote ? 1 : 0))
                self.debouncedSearchEngineResults(for: searchText, currentResults: finalResults,
                                                  insertIndex: insertIndex, onUpdateResultsBlock: onUpdateResultsBlock)

            }.store(in: &searchRequestsCancellables)
    }

    private func mergeAndSortPublishersResults(publishersResults: [AutocompletePublisherSourceResults],
                                               for searchText: String) -> (results: [AutocompleteResult], canCreateNote: Bool) {
        var autocompleteResults = [AutocompleteResult.Source: [AutocompleteResult]]()
        publishersResults.forEach { someResults in
            autocompleteResults[someResults.source, default: []].append(contentsOf: someResults.results)
        }
        if let noteResults = autocompleteResults[.note] {
            autocompleteResults[.note] = self.autocompleteResultsUnique(sequence: noteResults)
        }
        var finalResults = self.sortResults(notesResults: autocompleteResults[.note, default: []],
                                            historyResults: autocompleteResults[.history, default: []],
                                            urlResults: autocompleteResults[.url, default: []],
                                            topDomainResults: autocompleteResults[.topDomain, default: []])
        var canCreateNote = false
        if let createNoteResults = autocompleteResults[.createCard] {
            canCreateNote = true
            finalResults.append(contentsOf: createNoteResults)
        }

        return (results: finalResults, canCreateNote: canCreateNote)
    }

    private func debouncedSearchEngineResults(for searchText: String,
                                              currentResults: [AutocompleteResult],
                                              insertIndex: Int,
                                              onUpdateResultsBlock: (([AutocompleteResult]) -> Void)?) {
        searchEngineResultHandler = { [weak self] results in
            guard let self = self else { return }
            var newResults = currentResults
            let maxGuesses = newResults.count > 2 ? 4 : 6
            let toInsert = results.prefix(maxGuesses)
            let atIndex = insertIndex
            self.searchEngineTimeoutBlock?.cancel()
            if self.searchEngineTimeoutBlock != nil {
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
        searchEngineTimeoutBlock?.cancel()
        let block = DispatchWorkItem(block: {
            self.searchEngineTimeoutBlock = nil
            self.autocompleteResults = currentResults
            onUpdateResultsBlock?(currentResults)
        })
        searchEngineTimeoutBlock = block
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: block)
    }

    private func logAutocompleteResultFinished(for searchText: String, finalResults: [AutocompleteResult], startedAt: DispatchTime) {
        if !finalResults.isEmpty {
            Logger.shared.logDebug("-- Autosuggest results for `\(searchText)` --", category: .autocompleteManager)
            for result in finalResults {
                Logger.shared.logDebug("\(result.source) \(result.id) \(String(describing: result.url))", category: .autocompleteManager)
            }
        }
        let (elapsedTime, timeUnit) = startedAt.endChrono()
        Logger.shared.logInfo("autocomplete results in \(elapsedTime) \(timeUnit)", category: .autocompleteManager)
    }

    private func isResultCandidateForAutoselection(_ result: AutocompleteResult, forSearch searchText: String) -> Bool {
        switch result.source {
        case .history: return result.text.lowercased().starts(with: searchText.lowercased())
        case .url:
            guard let host = URL(string: result.text)?.host else { return false }
            return result.text.lowercased().contains(host)
        default:
            return false
        }
    }

    private func automaticallySelectFirstResultIfNeeded(withResults results: [AutocompleteResult], searchText: String) {
        if let firstResult = results.first, isResultCandidateForAutoselection(firstResult, forSearch: searchText) {
            autocompleteSelectedIndex = 0
        } else if autocompleteSelectedIndex == 0 {
            // first result was selected but is not matching anymore
            self.resetAutocompleteSelection(resetText: true)
        }
    }

    private func sortResults(notesResults: [AutocompleteResult], historyResults: [AutocompleteResult], urlResults: [AutocompleteResult], topDomainResults: [AutocompleteResult]) -> [AutocompleteResult] {
        // this logic should eventually become smarter to always include the right amount of result per source.

        var results = [AutocompleteResult]()

        let maxHistoryResults = notesResults.isEmpty ? 6 : 4
        let historyResultsTruncated = Array(historyResults.prefix(maxHistoryResults))

        let maxNotesSuggestions = historyResults.isEmpty ? 6 : 4
        let notesResultsTruncated = Array(notesResults.prefix(maxNotesSuggestions))

        let maxUrlSuggestions = urlResults.isEmpty ? 6 : 4
        let urlResultsTruncated = Array(urlResults.prefix(maxUrlSuggestions))

        results.append(contentsOf: urlResultsTruncated)
        results.append(contentsOf: notesResultsTruncated)
        results.append(contentsOf: historyResultsTruncated)

        results.sort(by: { (lhs, rhs) in
            let lhsr = lhs.text.lowercased().commonPrefix(with: lhs.completingText?.lowercased() ?? "").count
            let rhsr = rhs.text.lowercased().commonPrefix(with: rhs.completingText?.lowercased() ?? "").count
            return lhsr > rhsr
        })

        // Push top domain suggestion only when no other candidate is satisfying.
        if let topDomain = topDomainResults.first {
            if let topResult = results.first {
                if !isResultCandidateForAutoselection(topResult, forSearch: searchQuery) {
                    results.insert(topDomain, at: 0)
                }
            } else {
                results.insert(topDomain, at: 0)
            }
        }

        return results
    }


    private func updateSearchQueryWhenSelectingAutocomplete(_ selectedIndex: Int?, previousSelectedIndex: Int?) {
        if let i = selectedIndex, i >= 0, i < autocompleteResults.count {
            let result = autocompleteResults[i]
            var resultText = result.text
            textChangeIsFromSelection = true

            // if the first result is compatible with autoselection, select the added string
            if i == 0, let completingText = result.completingText,
               isResultCandidateForAutoselection(result, forSearch: completingText) {
                if result.source == .url {
                    if let resultTextDropped = resultText.dropBefore(substring: completingText) {
                        resultText = resultTextDropped
                    }
                }
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

    private func stopCurrentCompletionWork() {
        searchRequestsCancellables.forEach { $0.cancel() }
        searchRequestsCancellables.removeAll()
        searchEngineCompleter.clear()
        searchEngineTimeoutBlock?.cancel()
        searchEngineResultHandler = nil
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
        stopCurrentCompletionWork()
    }

    func resetQuery() {
        searchQuery = ""
        autocompleteResults = []
        stopCurrentCompletionWork()
    }

    func setQueryWithoutAutocompleting(_ query: String) {
        textChangeIsFromSelection = true
        searchQuery = query
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

    // MARK: - Animations
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

    func animateDirectQuery(with text: String?) {
        guard text != nil else {
            self.animatedQuery = nil
            return
        }
        var transaction = Transaction(animation: .interpolatingSpring(stiffness: 380, damping: 20))
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.animatedQuery = text
        }
    }
}
