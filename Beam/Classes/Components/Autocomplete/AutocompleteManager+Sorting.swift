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
        publishersResults.forEach { someResults in
            autocompleteResults[someResults.source, default: []].append(contentsOf: someResults.results)
        }
        if let noteResults = autocompleteResults[.note] {
            autocompleteResults[AutocompleteResult.Source.note] = self.autocompleteResultsUniqueNotes(sequence: noteResults)
        }
        let finalResults = sortResults(notesResults: autocompleteResults[.note, default: []],
                                            historyResults: autocompleteResults[.history] ?? [],
                                            urlResults: autocompleteResults[.url] ?? [],
                                            topDomainResults: autocompleteResults[.topDomain] ?? [],
                                            mnemonicResults: autocompleteResults[.mnemonic] ?? [],
                                            searchEngineResults: autocompleteResults[.autocomplete] ?? [],
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
        let notesResultsTruncated = Array(notesResults.prefix(6))
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

        let searchEngineResultsWithoutUniqueURLs = searchEngineResults.filter { r in
            guard r.source == .url, let url = r.url else { return true }
            return !uniqueURLs.contains { $0.url?.urlStringByRemovingUnnecessaryCharacters == url.urlStringByRemovingUnnecessaryCharacters }
        }
        let resultLimit = 8
        let results = merge(sortableResults: sortableResults,
                            searchEngineResults: searchEngineResultsWithoutUniqueURLs,
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

    private func autocompleteResultsUniqueNotes(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        var seenText = Set<String>()
        var seenUUID = Set<UUID>()

        return sequence.filter { seenText.update(with: $0.text) == nil && seenUUID.update(with: $0.uuid) == nil }
    }

    private func autocompleteResultsUniqueURLs(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
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
}
