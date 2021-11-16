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
    static let noteFrecencyParamKey: FrecencyParamKey = .note30d0
    static let urlFrecencyParamKey: FrecencyParamKey = .webVisit30d0

    @Published var searchQuery: String = ""

    private var textChangeIsFromSelection = false
    private var replacedProposedText: String?

    @Published var searchQuerySelectedRange: Range<Int>?
    @Published var autocompleteResults = [AutocompleteResult]()
    @Published var autocompleteSelectedIndex: Int? {
        didSet {
            updateSearchQueryWhenSelectingAutocomplete(autocompleteSelectedIndex, previousSelectedIndex: oldValue)
        }
    }

    @Published var animateInputingCharacter = false
    @Published var animatedQuery: String?
    let beamData: BeamData

    private let searchEngineCompleter: Autocompleter
    var searchEngine: SearchEngine {
        searchEngineCompleter.searchEngine
    }
    private var scope = Set<AnyCancellable>()
    var searchRequestsCancellables = Set<AnyCancellable>()

    init(with data: BeamData, searchEngine: SearchEngine) {
        beamData = data
        searchEngineCompleter = Autocompleter(searchEngine: searchEngine)

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
        let publishers = getAutocompletePublishers(for: searchText) +
            [getSearchEnginePublisher(for: searchText, searchEngine: searchEngineCompleter)]
        Publishers.MergeMany(publishers).collect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] publishersResults in
                guard let self = self else { return }
                let (finalResults, _) = self.mergeAndSortPublishersResults(publishersResults: publishersResults, for: searchText)
                self.logAutocompleteResultFinished(for: searchText, finalResults: finalResults, startedAt: startChrono)

                self.autocompleteResults = finalResults
                if !isRemovingCharacters {
                    self.automaticallySelectFirstResultIfNeeded(withResults: finalResults, searchText: searchText)
                }
            }.store(in: &searchRequestsCancellables)
    }

    private func logAutocompleteResultFinished(for searchText: String, finalResults: [AutocompleteResult], startedAt: DispatchTime) {
        if !finalResults.isEmpty {
            Logger.shared.logDebug("-- Autosuggest results for `\(searchText)` --", category: .autocompleteManager)
            for result in finalResults {
                Logger.shared.logDebug("\(String(describing: result))", category: .autocompleteManager)
            }
        }
        let (elapsedTime, timeUnit) = startedAt.endChrono()
        Logger.shared.logInfo("autocomplete results in \(elapsedTime) \(timeUnit)", category: .autocompleteManager)
    }

    static func logIntermediate(step: String, stepShortName: String, results: [AutocompleteResult], limit: Int = 10) {
        Logger.shared.logDebug("-------------\(step)-------------------", category: .autocompleteManager)
        for res in results.prefix(limit) {
            Logger.shared.logDebug("\(stepShortName): \(String(describing: res))", category: .autocompleteManager)
        }
        if results.count > limit {
            Logger.shared.logDebug("\(stepShortName): truncated results: \(results.count - limit)", category: .autocompleteManager)
        }
    }

    func isResultCandidateForAutoselection(_ result: AutocompleteResult, forSearch searchText: String) -> Bool {
        switch result.source {
        case .topDomain: return result.text.lowercased().starts(with: searchText.lowercased())
        case .history:
            if searchText.mayBeURL {
                guard let host = result.url?.minimizedHost ?? URL(string: result.text)?.minimizedHost else {
                    return false
                }
                return host.lowercased().starts(with: searchText.lowercased())
            }
            return result.text.lowercased().starts(with: searchText.lowercased())
        case .url:
            guard let host = result.url?.minimizedHost ?? URL(string: result.text)?.minimizedHost else { return false }
            return result.text.lowercased().contains(host)
        case .autocomplete:
            return autocompleteResults.count == 2 // 1 search engine result + 1 create card
            && !searchQuery.mayBeURL && result.text == searchQuery
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

    private func updateSearchQueryWhenSelectingAutocomplete(_ selectedIndex: Int?, previousSelectedIndex: Int?) {
        if let i = selectedIndex, i >= 0, i < autocompleteResults.count {
            let result = autocompleteResults[i]
            var resultText = result.text
            textChangeIsFromSelection = true

            // if the first result is compatible with autoselection, select the added string
            if i == 0, let completingText = result.completingText,
               isResultCandidateForAutoselection(result, forSearch: completingText) {
                if result.source == .url || result.source == .history {
                    if let resultTextDropped = resultText.dropBefore(substring: completingText) {
                        resultText = resultTextDropped
                    }
                }
                let completingTextEnd = completingText.wholeRange.upperBound
                let newSelection = completingTextEnd..<max(resultText.count, completingTextEnd)
                guard newSelection.count > 0 else { return }

                let resultPrefix = resultText.prefix(newSelection.lowerBound)
                guard resultPrefix.lowercased() == completingText.lowercased() else { return }

                let additionalText = resultText.substring(range: newSelection)
                searchQuery = completingText + additionalText
                searchQuerySelectedRange = newSelection
            } else if searchQuery != resultText {
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

    func isSentence(_ query: String) -> Bool {
        if query.numberOfWords > 1 {
            return true
        }
        return false
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
