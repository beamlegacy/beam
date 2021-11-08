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
        let finalResults = self.sortResults(notesResults: autocompleteResults[.note, default: []],
                                            historyResults: autocompleteResults[.history] ?? [],
                                            urlResults: autocompleteResults[.url] ?? [],
                                            topDomainResults: autocompleteResults[.topDomain] ?? [],
                                            searchEngineResults: autocompleteResults[.autocomplete] ?? [],
                                            createCardResults: autocompleteResults[.createCard] ?? [])

        let canCreateNote = autocompleteResults[.createCard]?.isEmpty == false
        return (results: finalResults, canCreateNote: canCreateNote)
    }

    private func findTopDomainIfNeeded(from results: [AutocompleteResult]) -> (results: [AutocompleteResult], topDomain: AutocompleteResult)? {
        var finalResults = results
        for (index, item) in finalResults.enumerated() {
            guard let itemUrl = item.url else { continue }
            if itemUrl.domainMatchWith(searchQuery) {
                finalResults.remove(at: index)
                return (results: finalResults, topDomain: item)
            }
        }
        return nil
    }

    private func sortResults(notesResults: [AutocompleteResult],
                             historyResults: [AutocompleteResult],
                             urlResults: [AutocompleteResult],
                             topDomainResults: [AutocompleteResult],
                             searchEngineResults: [AutocompleteResult],
                             createCardResults: [AutocompleteResult]) -> [AutocompleteResult] {
        var results = [AutocompleteResult]()

        var historyResultsTruncated = Array(historyResults.prefix(6))

        // but prioritize title match over content match ?
        let notesResultsTruncated = Array(notesResults.prefix(6))
        var urlResultsTruncated = Array(urlResults.prefix(6))
        var topHistoryDomainResult: AutocompleteResult?

        if searchQuery.mayBeWebURL || !isSentence(searchQuery) {
            if let urlResultsTopDomain = findTopDomainIfNeeded(from: urlResultsTruncated) {
                topHistoryDomainResult = urlResultsTopDomain.topDomain
                urlResultsTruncated = urlResultsTopDomain.results
            }
            if let historyResultsTopDomain = findTopDomainIfNeeded(from: historyResultsTruncated) {
                if topHistoryDomainResult == nil {
                    topHistoryDomainResult = historyResultsTopDomain.topDomain
                }
                historyResultsTruncated = historyResultsTopDomain.results
            }
            if let topDomain = topDomainResults.first, topHistoryDomainResult == nil {
                results.insert(topDomain, at: 0)
            }
        }

        var sortableResult = [AutocompleteResult]()
        sortableResult.append(contentsOf: autocompleteResultsUniqueUrls(sequence: historyResultsTruncated + urlResultsTruncated))
        sortableResult.append(contentsOf: notesResultsTruncated)

        sortableResult.sort(by: >)
        Self.logIntermediate(step: "SortableResults", stepShortName: "SR", results: sortableResult)
        let resultLimit = 8
        // leave space for at least 2 search engine result and 1 create card
        let hasCreateCard = !createCardResults.isEmpty
        let truncateLength = resultLimit - min(2, searchEngineResults.count) - (hasCreateCard ? 1 : 0)
        sortableResult = Array(sortableResult.prefix(truncateLength))
        let searchEngineMax = resultLimit - sortableResult.count - (hasCreateCard ? 1 : 0)
        sortableResult.insert(contentsOf: searchEngineResults.prefix(searchEngineMax), at: historyResultsTruncated.isEmpty && urlResultsTruncated.isEmpty && notesResultsTruncated.isEmpty ? 0 : 1)
        if let topHistoryDomainResult = topHistoryDomainResult {
            sortableResult.insert(topHistoryDomainResult, at: 0)
        }

        results.append(contentsOf: sortableResult)
        results = Array(results.prefix(resultLimit))

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
