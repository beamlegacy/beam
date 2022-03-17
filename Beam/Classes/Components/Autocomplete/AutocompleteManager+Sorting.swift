//
//  AutocompleteManager+Sorting.swift
//  Beam
//
//  Created by Remi Santos on 21/07/2021.
//

import Foundation

extension AutocompleteManager {
    private static let resultsLimit = 8

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
                                       expectSearchEngineResultsLater: mode == .general && !searchText.isEmpty,
                                       actionsResults: autocompleteResults[.action] ?? [],
                                       createCardResults: autocompleteResults[.createNote] ?? [])

        let canCreateNote = autocompleteResults[.createNote]?.isEmpty == false
        return (results: finalResults, canCreateNote: canCreateNote)
    }

    //swiftlint:disable:next function_parameter_count
    private func sortResults(notesResults: [AutocompleteResult],
                             historyResults: [AutocompleteResult],
                             urlResults: [AutocompleteResult],
                             topDomainResults: [AutocompleteResult],
                             mnemonicResults: [AutocompleteResult],
                             searchEngineResults: [AutocompleteResult],
                             expectSearchEngineResultsLater: Bool,
                             actionsResults: [AutocompleteResult],
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

        let results = merge(sortableResults: sortableResults,
                            searchEngineResults: filteredSearchEngineResults,
                            actionsResults: actionsResults,
                            createCardResults: createCardResults,
                            limit: Self.resultsLimit,
                            expectSearchEngineResultsLater: expectSearchEngineResultsLater)
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
                       actionsResults: [AutocompleteResult],
                       createCardResults: [AutocompleteResult],
                       limit: Int,
                       expectSearchEngineResultsLater: Bool) -> [AutocompleteResult] {
        let hasCreateCard = !createCardResults.isEmpty
        var searchEngineSpace: Int = 0
        // leave space for at least 2 search engine result, even if they arrive later.
        if !searchEngineResults.isEmpty || expectSearchEngineResultsLater {
            searchEngineSpace = searchEngineResults.count > 0 ? min(2, searchEngineResults.count) : 2
        }
        let truncateLength = limit - searchEngineSpace - (hasCreateCard ? 1 : 0) - actionsResults.count
        var results = Array(sortableResults.prefix(truncateLength))
        let searchEngineMax = truncateLength - results.count + searchEngineSpace
        results.insert(contentsOf: searchEngineResults.prefix(searchEngineMax), at: sortableResults.isEmpty ? 0 : 1)
        results.append(contentsOf: actionsResults)
        if mode == .noteCreation {
            results.insert(contentsOf: createCardResults, at: 0)
        } else {
            results.append(contentsOf: createCardResults)
        }
        return results
    }

    func insertSearchEngineResults(_ searchEngineResults: [AutocompleteResult],
                                   in results: [AutocompleteResult]) -> [AutocompleteResult] {
        let limit = Self.resultsLimit
        var finalResults = results
        let existingAutocompleteResult = finalResults.filter { $0.source == .searchEngine }

        let maxGuesses = max(2, limit - finalResults.count)
        let filteredSearchResults = searchEngineResults.filter { result in
            !existingAutocompleteResult.contains { $0.text == result.text }
        }.prefix(maxGuesses)
        let insertionIndex: Int
        if let lastPriority = finalResults.lastIndex(where: { $0.source > AutocompleteResult.Source.searchEngine }) {
            insertionIndex = lastPriority + 1
        } else {
            insertionIndex = 0
        }
        if insertionIndex <= finalResults.count {
            finalResults.insert(contentsOf: filteredSearchResults, at: insertionIndex)
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
        // Take all the results and deduplicate them based on their urls, priority and score
        var uniqueURLs = [String: Int]()
        var finalList = [AutocompleteResult]()
        for result in sequence {
            let id = result.url?.urlStringByRemovingUnnecessaryCharacters.lowercased() ?? result.text.lowercased()
            if let existingIndex = uniqueURLs[id] {
                let existing = finalList[existingIndex]
                if result.source > existing.source || (result.source == existing.source && result > existing) {
                    uniqueURLs[id] = existingIndex
                    finalList.remove(at: existingIndex)
                    finalList.insert(result, at: existingIndex)
                }
            } else {
                uniqueURLs[id] = finalList.count
                finalList.append(result)
            }
        }
        return finalList.sorted(by: >)
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
            return !urlResults.contains { $0.url?.urlStringByRemovingUnnecessaryCharacters.lowercased() == url.urlStringByRemovingUnnecessaryCharacters.lowercased() }
        }
    }
}
