//
//  AutocompleteManager+Sorting.swift
//  Beam
//
//  Created by Remi Santos on 21/07/2021.
//

import Foundation

extension AutocompleteManager {

    func mergeAndSortPublishersResults(publishersResults: [AutocompletePublisherSourceResults],
                                       for searchText: String) -> (results: [AutocompleteResult], canCreateNote: Bool) {
        var autocompleteResults = [AutocompleteResult.Source: [AutocompleteResult]]()
        var additionalSearchEngineResults = [AutocompleteResult]()
        publishersResults.forEach { someResults in
            switch someResults.source {
            case .history, .url: // these sources can contain search engine like results.
                someResults.results.forEach { result in
                    switch result.source {
                    case .searchEngine:
                        additionalSearchEngineResults.append(result)
                    default:
                        autocompleteResults[result.source, default: []].append(result)
                    }
                }
            default:
                autocompleteResults[someResults.source, default: []].append(contentsOf: someResults.results)
            }
        }
        if !additionalSearchEngineResults.isEmpty {
            autocompleteResults[.searchEngine, default: []].insert(contentsOf: additionalSearchEngineResults.sorted(by: >), at: 0)
        }

        let finalResults = sortResults(notesResults: autocompleteResults[.note, default: []],
                                       historyResults: autocompleteResults[.history] ?? [],
                                       urlResults: autocompleteResults[.url] ?? [],
                                       topDomainResults: autocompleteResults[.topDomain] ?? [],
                                       mnemonicResults: autocompleteResults[.mnemonic] ?? [],
                                       searchEngineResults: autocompleteResults[.searchEngine] ?? [],
                                       createCardResults: autocompleteResults[.createCard] ?? [])

        let canCreateNote = autocompleteResults[.createCard]?.isEmpty == false
        return (results: finalResults, canCreateNote: canCreateNote)
    }

    //swiftlint:disable:next function_parameter_count
    private func sortResults(notesResults: [AutocompleteResult],
                             historyResults: [AutocompleteResult],
                             urlResults: [AutocompleteResult],
                             topDomainResults: [AutocompleteResult],
                             mnemonicResults: [AutocompleteResult],
                             searchEngineResults: [AutocompleteResult],
                             createCardResults: [AutocompleteResult]) -> [AutocompleteResult] {
        let start = DispatchTime.now()
        let historyResultsTruncated = Array(historyResults.prefix(6))

        // but prioritize title match over content match ?
        let notesResultsTruncated = Array(autocompleteResultsUniqueNotes(sequence: notesResults).prefix(6))
        let urlResultsTruncated = Array(urlResults.prefix(6))

        var sortableResults = [AutocompleteResult]()
        let uniqueURLs = autocompleteResultsUniqueURLs(sequence: historyResultsTruncated + urlResultsTruncated)
        self.rawSortedURLResults = uniqueURLs
        sortableResults.append(contentsOf: uniqueURLs)
        sortableResults.append(contentsOf: notesResultsTruncated)

        sortableResults.sort(by: >)
        Self.logIntermediate(step: "SortableResults", stepShortName: "SR", results: sortableResults, startedAt: start)

        sortableResults = boostResult(topDomainResults, results: sortableResults)
        sortableResults = boostResult(mnemonicResults, results: sortableResults)

        var filteredSearchEngineResults = filterOutSearchEngineURLResults(from: searchEngineResults, forURLAlreadyIn: uniqueURLs)
        filteredSearchEngineResults = autocompleteResultsUniqueSearchEngine(sequence: filteredSearchEngineResults)

        let resultLimit = 8
        let results = merge(sortableResults: sortableResults,
                            searchEngineResults: filteredSearchEngineResults,
                            createCardResults: createCardResults,
                            limit: resultLimit)
        return results
    }

    private func boostResult(_ partialResults: [AutocompleteResult], results: [AutocompleteResult]) -> [AutocompleteResult] {
        guard let partialResult = partialResults.first else { return results }

        // Push top domain suggestion only when the first result is not satisfying.
        guard let firstResult = results.first,
           isResultCandidateForAutoselection(firstResult, forSearch: firstResult.completingText ?? "")
        else {
            return [partialResult] + results
        }

        return results
    }

    private func merge(sortableResults: [AutocompleteResult],
                       searchEngineResults: [AutocompleteResult],
                       createCardResults: [AutocompleteResult],
                       limit: Int) -> [AutocompleteResult] {
        // leave space for at least 2 search engine result and 1 create card
        let hasCreateCard = !createCardResults.isEmpty
        let truncateLength = limit - min(2, searchEngineResults.count) - (hasCreateCard ? 1 : 0)
        var results = Array(sortableResults.prefix(truncateLength))
        let searchEngineMax = limit - results.count - (hasCreateCard ? 1 : 0)
        results.insert(contentsOf: searchEngineResults.prefix(searchEngineMax), at: sortableResults.isEmpty ? 0 : 1)
        results.append(contentsOf: createCardResults)
        return results
    }

    func insertSearchEngineResults(_ searchEngineResults: [AutocompleteResult], in results: [AutocompleteResult]) -> [AutocompleteResult] {
        var finalResults = results
        let canCreate = finalResults.firstIndex { $0.source == .createCard } != nil
        let existingAutocompleteResult = finalResults.filter { $0.source == .searchEngine }

        let maxGuesses = finalResults.count > 2 ? 4 : 6
        let toInsert = searchEngineResults.filter { result in
            !existingAutocompleteResult.contains { $0.text == result.text }
        }.prefix(maxGuesses)
        let atIndex = max(0, finalResults.count - (canCreate ? 1 : 0))
        if atIndex <= finalResults.count {
            finalResults.insert(contentsOf: toInsert, at: atIndex)
        }
        return finalResults
    }
}

// MARK: - Deduplicate
extension AutocompleteManager {

    internal func autocompleteResultsUniqueNotes(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        var seenText = Set<String>()
        var seenUUID = Set<UUID>()

        return sequence.filter { seenText.update(with: $0.text) == nil && seenUUID.update(with: $0.uuid) == nil }
    }

    internal func autocompleteResultsUniqueURLs(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        // Take all the results and deduplicate the results based on their urls and source priorities:
        var uniqueURLs = [String: AutocompleteResult]()
        for result in sequence {
            let id = result.url?.urlStringByRemovingUnnecessaryCharacters ?? result.text
            if let existing = uniqueURLs[id] {
                if result.source.priority < existing.source.priority ||
                    (result.score != nil && (existing.score == nil || result.score ?? 0 > existing.score ?? 0)) {
                    uniqueURLs[id] = result
                }
            } else {
                uniqueURLs[id] = result
            }
        }
        return Array(uniqueURLs.values).sorted(by: >)
    }

    internal func autocompleteResultsUniqueSearchEngine(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        // Take all the results and deduplicate the results based on their search text and engine
        var uniqueResults = [String: AutocompleteResult]()
        var toRemoveIndexes = [Int]()
        for (index, result) in sequence.enumerated() {
            let id = result.text + (result.information ?? "")
            if let existing = uniqueResults[id] {
                if result.score != nil && (existing.score == nil || result.score ?? 0 > existing.score ?? 0) {
                    if let existingIndex = sequence.firstIndex(of: existing) {
                        toRemoveIndexes.append(existingIndex)
                    }
                    uniqueResults[id] = result
                } else {
                    toRemoveIndexes.append(index)
                }
            } else {
                uniqueResults[id] = result
            }
        }
        let finalResult = sequence.enumerated().compactMap {
            toRemoveIndexes.contains($0.0) ? nil : $0.1
        }
        return finalResult
    }

    internal func filterOutSearchEngineURLResults(from sequence: [AutocompleteResult], forURLAlreadyIn urlResults: [AutocompleteResult]) -> [AutocompleteResult] {
        sequence.filter { r in
            guard r.source == .url, let url = r.url else { return true }
            return !urlResults.contains { $0.url?.urlStringByRemovingUnnecessaryCharacters == url.urlStringByRemovingUnnecessaryCharacters }
        }
    }
}
