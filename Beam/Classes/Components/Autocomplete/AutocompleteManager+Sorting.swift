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
                                            searchEngineResults: autocompleteResults[.autocomplete] ?? [],
                                            createCardResults: autocompleteResults[.createCard] ?? [])

        let canCreateNote = autocompleteResults[.createCard]?.isEmpty == false
        return (results: finalResults, canCreateNote: canCreateNote)
    }

    private func sortResults(notesResults: [AutocompleteResult],
                             historyResults: [AutocompleteResult],
                             urlResults: [AutocompleteResult],
                             topDomainResults: [AutocompleteResult],
                             searchEngineResults: [AutocompleteResult],
                             createCardResults: [AutocompleteResult]) -> [AutocompleteResult] {
        let start = DispatchTime.now()
        let historyResultsTruncated = Array(historyResults.prefix(6))

        // but prioritize title match over content match ?
        let notesResultsTruncated = Array(notesResults.prefix(6))
        let urlResultsTruncated = Array(urlResults.prefix(6))

        var sortableResults = [AutocompleteResult]()
        sortableResults.append(contentsOf: autocompleteResultsUniqueUrls(sequence: historyResultsTruncated + urlResultsTruncated))
        sortableResults.append(contentsOf: notesResultsTruncated)

        sortableResults.sort(by: >)
        Self.logIntermediate(step: "SortableResults", stepShortName: "SR", results: sortableResults, startedAt: start)

        if let topDomain = topDomainResults.first {
            if let firstResult = sortableResults.first,
                isResultCandidateForAutoselection(firstResult, forSearch: firstResult.completingText ?? "") {
                    // Push top domain suggestion only when the first result is not satisfying.
            } else {
                sortableResults.insert(topDomain, at: 0)
            }
        }
        let resultLimit = 8
        let results = merge(sortableResults: sortableResults,
                            searchEngineResults: searchEngineResults,
                            createCardResults: createCardResults,
                            limit: resultLimit)
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

    private func autocompleteResultsUniqueUrls(sequence: [AutocompleteResult]) -> [AutocompleteResult] {
        var seenUrl = Set<String>()
        return sequence.filter { seenUrl.update(with: $0.url?.urlStringByRemovingUnnecessaryCharacters ?? $0.text) == nil }
    }
}
