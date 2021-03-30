//
//  AutocompleteManager.swift
//  Beam
//
//  Created by Remi Santos on 29/03/2021.
//

import Foundation
import Combine

// BeamState Autocomplete management
class AutocompleteManager: ObservableObject {

    @Published var searchQuery: String = ""
    @Published var searchQuerySelectedRanges: [Range<Int>]?
    @Published var autocompleteResults = [AutocompleteResult]()
    @Published var autocompleteSelectedIndex: Int? = nil {
        didSet {
            updateSearchQueryWhenSelectingAutocomplete(autocompleteSelectedIndex, previousSelectedIndex: oldValue)
        }
    }

    private var autocompleteSearchGuessesHandler: (([AutocompleteResult]) -> Void)?
    private var autocompleteTimeoutBlock: DispatchWorkItem?
    private let beamData: BeamData
    private let searchCompleter = Completer()
    private var scope = Set<AnyCancellable>()

    init(with data: BeamData) {
        self.beamData = data

        $searchQuery.sink { [weak self] query in
            guard let self = self else { return }
            self.buildAutocompleteResults(for: query)
        }.store(in: &scope)

        searchCompleter.$results.receive(on: RunLoop.main).sink { [weak self] results in
            guard let self = self, let guessesHandler = self.autocompleteSearchGuessesHandler else { return }
            guessesHandler(results)
        }.store(in: &scope)
    }

    func selectPreviousAutocomplete() {
        if let i = autocompleteSelectedIndex {
            let newIndex = i - 1
            if newIndex >= 0 {
                autocompleteSelectedIndex = newIndex
            } else {
                resetAutocompleteSelection()
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
        searchQuerySelectedRanges = nil
        autocompleteSelectedIndex = nil
    }

    func cancelAutocomplete() {
        resetAutocompleteSelection()
        autocompleteResults = []
    }

    func resetQuery() {
        searchQuery = ""
        autocompleteResults = []
    }

    private func autocompleteNotesResults(for query: String) -> [AutocompleteResult] {
        return beamData.documentManager.documentsWithTitleMatch(title: query)
            // Eventually, we should not show notes under a certain score threshold
            // Disabling it for now until we have a better scoring system
            // .compactMap({ doc -> DocumentStruct? in
            //      let decoder = JSONDecoder()
            //      decoder.userInfo[BeamElement.recursiveCoding] = false
            //      guard let note = try? decoder.decode(BeamNote.self, from: doc.data)
            //      else { Logger.shared.logError("unable to partially decode note '\(doc.title)'", category: .document); return nil }
            //      Logger.shared.logDebug("Filtering note '\(note.title)' -> \(note.score)", category: .general)
            //      return note.score >= NoteDisplayThreshold ? doc : nil
            // })
            .map { AutocompleteResult(text: $0.title, source: .note, completingText: query, uuid: $0.id) }
    }

    private func autocompleteHistoryResults(for query: String) -> [AutocompleteResult] {
        return self.beamData.index.search(string: query).map {
            var urlString = $0.source
            let url = URL(string: urlString)
            if let url = url {
                urlString = url.urlStringWithoutScheme
            }
            return AutocompleteResult(text: $0.title, source: .history, url: url, information: urlString, completingText: query)
        }
    }

    func buildAutocompleteResults(for query: String) {
        guard self.searchQuerySelectedRanges == nil else { return }
        guard self.autocompleteSelectedIndex == nil else { return }
        // Logger.shared.logDebug("received auto complete query: \(query)")

        guard !query.isEmpty else {
            self.autocompleteResults = []
            return
        }
        var finalResults = [AutocompleteResult]()

        // #1 Exisiting Notes
        let notesResults = autocompleteNotesResults(for: query)

        // #2 History results
        let historyResults = autocompleteHistoryResults(for: query)

        finalResults = sortResults(notesResults: notesResults, historyResults: historyResults)

        // #3 Create Card
        let canCreateNote = BeamNote.fetch(beamData.documentManager, title: query) == nil && URL(string: query)?.scheme == nil
        if canCreateNote {
            // if the card doesn't exist, propose to create it
            finalResults.append(AutocompleteResult(text: query, source: .createCard, information: "New card", completingText: query))
        }

        if query.count > 1 {
            // #4 Search Autocomplete results
            autocompleteSearchGuessesHandler = { [weak self] results in
                guard let self = self else { return }
                //Logger.shared.logDebug("received auto complete results: \(results)")
                self.autocompleteSelectedIndex = nil
                let maxGuesses = finalResults.count > 2 ? 4 : 6
                let toInsert = results.prefix(maxGuesses)
                let atIndex = finalResults.count - (canCreateNote ? 1 : 0)
                if self.autocompleteTimeoutBlock != nil {
                    self.autocompleteTimeoutBlock?.cancel()
                    finalResults.insert(contentsOf: toInsert, at: atIndex)
                    self.autocompleteResults = finalResults
                } else {
                    self.autocompleteResults.insert(contentsOf: toInsert, at: atIndex)
                }
            }
            self.searchCompleter.complete(query: query)

            autocompleteTimeoutBlock?.cancel()
            autocompleteTimeoutBlock = DispatchWorkItem(block: {
                self.autocompleteTimeoutBlock = nil
                self.autocompleteResults = finalResults
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: autocompleteTimeoutBlock!)
        } else {
            autocompleteSearchGuessesHandler = nil
            self.autocompleteResults = finalResults
        }
    }

    func sortResults(notesResults: [AutocompleteResult], historyResults: [AutocompleteResult]) -> [AutocompleteResult] {
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

    func updateSearchQueryWhenSelectingAutocomplete(_ selectedIndex: Int?, previousSelectedIndex: Int?) {
        if let i = autocompleteSelectedIndex, i >= 0, i < autocompleteResults.count {
            let result = autocompleteResults[i]
            let resultText = result.text
            let oldSize = searchQuerySelectedRanges?.first?.startIndex ?? searchQuery.count
            let newSize = resultText.count
            var unselectedPrefix = searchQuery.substring(from: 0, to: oldSize).lowercased()
            if unselectedPrefix.isEmpty {
                unselectedPrefix = result.completingText?.lowercased() ?? ""
            }
            // If the completion shares a common root with the original query, select the portion that is different
            // otherwise select the whole string so that the next keystroke replaces everything
            let newSelection = [(resultText.hasPrefix(unselectedPrefix) ? unselectedPrefix.wholeRange.upperBound : 0) ..< newSize]
            searchQuery = resultText
            searchQuerySelectedRanges = newSelection
        } else if let previousValue = previousSelectedIndex,
                  previousValue < autocompleteResults.count,
                  autocompleteSelectedIndex == nil, searchQuerySelectedRanges != nil {
            let previousResult = autocompleteResults[previousValue]
            searchQuerySelectedRanges = nil
            searchQuery = previousResult.completingText ?? ""
        }
    }
}
