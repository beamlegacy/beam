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

/// Omnibox results management
class AutocompleteManager: ObservableObject {
    static let noteFrecencyParamKey: FrecencyParamKey = .note30d0
    static let urlFrecencyParamKey: FrecencyParamKey = .webVisit30d0

    @Published var mode: Mode = .general
    @Published var searchQuery: String = ""
    weak private(set) var beamState: BeamState?

    private var textChangeIsFromSelection = false
    private var replacedProposedText: String?
    private var autocompleteResultsAreFromEmptyQuery = false

    @Published var searchQuerySelectedRange: Range<Int>?
    @Published private(set) var autocompleteResults = [AutocompleteResult]()
    @Published var rawAutocompleteResults = [AutocompletePublisherSourceResults]()
    @Published var rawSortedURLResults = [AutocompleteResult]()

    @Published var autocompleteSelectedIndex: Int? {
        didSet {
            updateSearchQueryWhenSelectingAutocomplete(autocompleteSelectedIndex, previousSelectedIndex: oldValue)
        }
    }

    @Published var animateInputingCharacter = false
    @Published var isPreparingForAnimatingToMode = false
    @Published var animatingToMode: Mode?

    let searchEngineCompleter: SearchEngineAutocompleter
    var searchEngine: SearchEngineDescription {
        searchEngineCompleter.searchEngine
    }
    private var scope = Set<AnyCancellable>()
    var searchRequestsCancellables = Set<AnyCancellable>()

    init(searchEngine: SearchEngineDescription, beamState: BeamState?) {
        searchEngineCompleter = SearchEngineAutocompleter(searchEngine: searchEngine)
        self.beamState = beamState
        $searchQuery
            .dropFirst()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.buildAutocompleteResults(for: query)
            }.store(in: &scope)
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

    /// Called right before showing the omnibox;
    /// to make sure we have the expected results before any animation
    func prepareResultsForAppearance(for receivedQueryString: String, completion: (() -> Void)? = nil) {
        guard shouldDisplayDefaultSuggestions(for: receivedQueryString) else { return }
        buildAutocompleteResults(for: receivedQueryString) {
            completion?()
        }
    }

    private func buildAutocompleteResults(for receivedQueryString: String, completion: (() -> Void)? = nil) {
        guard !textChangeIsFromSelection else {
            textChangeIsFromSelection = false
            return
        }
        let startChrono = DispatchTime.now()

        var searchText = receivedQueryString
        let previousUnselectedText = getUnselectedText(for: searchQuery)?.lowercased() ?? searchQuery
        let isRemovingCharacters = searchText.count < previousUnselectedText.count || searchText.lowercased() == previousUnselectedText
        var selectionWasReset = false
        if let realText = replacedProposedText {
            searchText = realText
            replacedProposedText = nil
        } else if !isRemovingCharacters && !shouldResetSelectionBeforeNewResults() {
            // if we autoselect a search engine result that is alone,
            // let's the keep selection until have new results.
        } else {
            selectionWasReset = true
            self.resetAutocompleteSelection()
        }

        stopCurrentCompletionWork()
        var publishers: [AnyPublisher<AutocompleteManager.AutocompletePublisherSourceResults, Never>]
        if shouldDisplayDefaultSuggestions(for: searchText) {
            publishers = getDefaultSuggestionsPublishers()
        } else {
            publishers = getAutocompletePublishers(for: searchText)
            #if DEBUG
            // Use this to help you recreate situation producing bugs.
            //  publishers = getAutocompleteMockPublishers(for: searchText)
            #endif
        }

        Logger.shared.logInfo("------------------- ✳️ Start of autocomplete for \(receivedQueryString) -------------------", category: .autocompleteManager)

        Publishers.MergeMany(publishers).collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] publishersResults in
                defer {
                    completion?()
                }
                guard let self = self else { return }
                self.rawAutocompleteResults = publishersResults.compactMap({ $0.results.isEmpty ? nil : $0 })
                let (finalResults, _) = self.mergeAndSortPublishersResults(publishersResults: publishersResults, for: searchText,
                                                                           expectSearchEngineResultsLater: self.mode == .general && !searchText.isEmpty)
                self.logAutocompleteResultFinished(for: searchText, finalResults: finalResults, startedAt: startChrono)

                self.autocompleteResultsAreFromEmptyQuery = searchText.isEmpty
                self.setAutocompleteResults(finalResults)
                if !isRemovingCharacters {
                    self.automaticallySelectFirstResultIfNeeded(withResults: finalResults, searchText: searchText, canResetText: selectionWasReset)
                }
            }.store(in: &searchRequestsCancellables)
    }

    private func shouldDisplayDefaultSuggestions(for searchText: String) -> Bool {
        searchText.isEmpty ||
        (beamState?.omniboxInfo.isFocusedFromTab == true && searchText == beamState?.browserTabsManager.currentTab?.url?.absoluteString)
    }

    private func logAutocompleteResultFinished(for searchText: String, finalResults: [AutocompleteResult], startedAt: DispatchTime) {
        if !finalResults.isEmpty {
            Logger.shared.logDebug("------------------- Autosuggest results for `\(searchText)` -------------------", category: .autocompleteManager)
            for result in finalResults {
                Logger.shared.logDebug("\(String(describing: result))", category: .autocompleteManager)
            }
        }
        let (elapsedTime, timeUnit) = startedAt.endChrono()
        Logger.shared.logInfo("------------------- ✅ End of autocomplete. results in \(elapsedTime) \(timeUnit) -------------------", category: .autocompleteManager)
    }

    static func logIntermediate(step: String, stepShortName: String, results: [AutocompleteResult], limit: Int = 10, startedAt: DispatchTime) {

        let (elapsedTime, timeUnit) = startedAt.endChrono()
        Logger.shared.logDebug("-------------------\(step)-------------------", category: .autocompleteManager)
        Logger.shared.logDebug("------------------- Took \(elapsedTime) \(timeUnit)-------------------", category: .autocompleteManager)

        for res in results.prefix(limit) {
            Logger.shared.logDebug("\(stepShortName): \(String(describing: res))", category: .autocompleteManager)
        }
        if results.count > limit {
            Logger.shared.logDebug("\(stepShortName): truncated results: \(results.count - limit)", category: .autocompleteManager)
        }
    }

    private func shouldResetSelectionBeforeNewResults() -> Bool {
        guard mode != .noteCreation else { return false } // note creation always auto select
        if autocompleteSelectedIndex == 0 && autocompleteResults.first?.source == .searchEngine {
            // selected search enginer result will most likely be auto selected on next input
            return false
        }
        return true
    }

    func isResultCandidateForAutoselection(_ result: AutocompleteResult, forSearch searchText: String) -> Bool {
        switch result.source {
        case .mnemonic: return true // a mnemonic is by definition something that can take over the result
        case .topDomain:
            return result.text.lowercased().starts(with: searchText.lowercased())
        case .history, .url:
            return result.takeOverCandidate
        case .searchEngine:
            return result.takeOverCandidate && result.url != nil || // search engine result found in history 
            (autocompleteResults.count == 2 && !searchQuery.mayBeURL && result.text == searchQuery) // 1 search engine result + 1 create note
        case .createNote where mode == .noteCreation:
            return true
        default:
            return false
        }
    }

    private func automaticallySelectFirstResultIfNeeded(withResults results: [AutocompleteResult], searchText: String, canResetText: Bool = true) {
        if let firstResult = results.first, isResultCandidateForAutoselection(firstResult, forSearch: searchText) {
            autocompleteSelectedIndex = 0
        } else if autocompleteSelectedIndex == 0 {
            // first result was selected but is not matching anymore
            self.resetAutocompleteSelection(resetText: canResetText)
        }
    }

    private func updateSearchQueryWhenSelectingAutocomplete(_ selectedIndex: Int?, previousSelectedIndex: Int?) {
        guard let i = selectedIndex, i >= 0, i < autocompleteResults.count else { return }
        guard mode != .noteCreation else { return }

        let result = autocompleteResults[i]
        let resultText = result.displayText

        // if the first result is compatible with autoselection, select the added string
        if i == 0, let completingText = result.completingText,
           isResultCandidateForAutoselection(result, forSearch: completingText) {
            let completingTextEnd = completingText.wholeRange.upperBound
            var newSelection = completingTextEnd..<max(resultText.count, completingTextEnd)
            var queryToSet: String?
            if newSelection.count > 0 && resultText.prefix(newSelection.lowerBound).lowercased() == completingText.lowercased() {
                let additionalText = resultText.substring(range: newSelection)
                queryToSet = completingText + additionalText
            } else if searchQuery != completingText && searchQuerySelectedRange?.isEmpty != true {
                queryToSet = completingText
                newSelection = completingText.count..<completingText.count
            }

            if let queryToSet = queryToSet {
                setQuery(queryToSet, updateAutocompleteResults: false)
                searchQuerySelectedRange = newSelection
            }
        } else if searchQuery != resultText {
            setQuery(resultText, updateAutocompleteResults: false)
            searchQuerySelectedRange = resultText.count..<resultText.count
        }
    }

    private func resetAutocompleteSelection(resetText: Bool) {
        if resetText, let previousResult = autocompleteResult(at: autocompleteSelectedIndex) {
            setQuery(previousResult.completingText ?? "", updateAutocompleteResults: false)
        }
        searchQuerySelectedRange = nil
        autocompleteSelectedIndex = nil
    }

    private func stopCurrentCompletionWork() {
        searchRequestsCancellables.forEach { $0.cancel() }
        searchRequestsCancellables.removeAll()
    }
}

// MARK: - Public methods
extension AutocompleteManager {

    func autocompleteResult(at index: Int?) -> AutocompleteResult? {
        guard let index = index, index >= 0 && index < autocompleteResults.count else { return nil }
        return autocompleteResults[index]
    }

    func selectPreviousAutocomplete() {
        if let i = autocompleteSelectedIndex {
            let newIndex = i - 1
            if newIndex >= 0 {
                autocompleteSelectedIndex = newIndex
            } else {
                resetAutocompleteSelection(resetText: true)
            }
        } else if autocompleteResults.count > 0 {
            autocompleteSelectedIndex = (-1).clampInLoop(0, autocompleteResults.count - 1)
        }
    }

    func selectNextAutocomplete() {
        if let i = autocompleteSelectedIndex {
            autocompleteSelectedIndex = (i + 1).clampInLoop(0, autocompleteResults.count - 1)
        } else if autocompleteResults.count > 0 {
            autocompleteSelectedIndex = 0
        }
    }

    func handleLeftRightCursorMovement(_ cursorMovement: CursorMovement) -> Bool {
        switch cursorMovement {
        case .right:
            if let url = autocompleteResult(at: autocompleteSelectedIndex)?.url, searchQuery != url.urlStringWithoutScheme {
                let newQuery = url.scheme?.contains("http") == true ? url.urlStringWithoutScheme : url.absoluteString
                setQuery(newQuery, updateAutocompleteResults: false)
            }
            resetAutocompleteSelection()
            return false
        case .left:
            if autocompleteSelectedIndex != nil, let selectedTextRange = searchQuerySelectedRange, !selectedTextRange.isEmpty {
                searchQuery = searchQuery.substring(from: 0, to: selectedTextRange.lowerBound)
            }
            resetAutocompleteSelection()
            return false
        default:
            return false
        }
    }

    func resetAutocompleteSelection() {
        resetAutocompleteSelection(resetText: false)
    }

    func setAutocompleteResults(_ newResults: [AutocompleteResult], animated: Bool = true) {
        if animated {
            withAnimation(BeamAnimation.easeInOut(duration: 0.3)) {
                autocompleteResults = newResults
            }
        } else {
            autocompleteResults = newResults
        }
    }

    func clearAutocompleteResults(animated: Bool = true) {
        resetAutocompleteSelection()
        setAutocompleteResults([], animated: animated)
        autocompleteResultsAreFromEmptyQuery = false
        stopCurrentCompletionWork()
    }

    func resetQuery() {
        setQuery("", updateAutocompleteResults: false)
        if !autocompleteResultsAreFromEmptyQuery {
            clearAutocompleteResults(animated: false)
        }
        mode = .general
        stopCurrentCompletionWork()
    }

    func setQuery(_ query: String, updateAutocompleteResults: Bool) {
        textChangeIsFromSelection = !updateAutocompleteResults
        searchQuery = query
    }

    func getEmptyQuerySuggestions() {
        guard searchQuery.isEmpty else { return }
        buildAutocompleteResults(for: searchQuery)
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
              unselectedProposedText.count == selectedRange.lowerBound + 1,
              unselectedProposedText.last?.lowercased() == selectedText.first?.lowercased()
        else {
            if proposedText.isEmpty {
                resetAutocompleteSelection(resetText: false)
            }
            return nil
        }

        replacedProposedText = unselectedProposedText
        let newRange = unselectedProposedText.count..<currentText.count
        searchQuerySelectedRange = unselectedProposedText.count..<currentText.count
        let newText = unselectedProposedText + currentText.substring(range: newRange)
        return (newText, newRange)
    }

    func isSentence(_ query: String) -> Bool {
        if query.numberOfWords > 1 {
            return true
        }
        return false
    }
}

extension AutocompleteManager {
    enum Mode {
        case noteCreation
        case general
    }
}
