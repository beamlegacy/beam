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

    private func sortResults(notesResults: [AutocompleteResult],
                             historyResults: [AutocompleteResult],
                             urlResults: [AutocompleteResult],
                             topDomainResults: [AutocompleteResult],
                             searchEngineResults: [AutocompleteResult],
                             createCardResults: [AutocompleteResult]) -> [AutocompleteResult] {
        var results = [AutocompleteResult]()

        let historyResultsTruncated = Array(historyResults.prefix(6))

        // but prioritize title match over content match ?
        let notesResultsTruncated = Array(notesResults.prefix(6))
        let urlResultsTruncated = Array(urlResults.prefix(6))

        results.append(contentsOf: urlResultsTruncated)
        results.append(contentsOf: notesResultsTruncated)
        results.append(contentsOf: historyResultsTruncated)

        results.sort(by: { (lhs, rhs) in
            let lhsr = lhs.text.lowercased().commonPrefix(with: lhs.completingText?.lowercased() ?? "").count
            let rhsr = rhs.text.lowercased().commonPrefix(with: rhs.completingText?.lowercased() ?? "").count
            return lhsr > rhsr
        })

        if let topDomain = topDomainResults.first {
            if let firstResult = results.first,
               isResultCandidateForAutoselection(firstResult, forSearch: firstResult.completingText ?? "") {
                // Push top domain suggestion only when the first result is not satisfying.
            } else {
                results.insert(topDomain, at: 0)
            }
        }

        let resultLimit = 8
        // leave space for at least 2 search engine result and 1 create card
        let hasCreateCard = !createCardResults.isEmpty
        let truncateLength = resultLimit - min(2, searchEngineResults.count) - (hasCreateCard ? 1 : 0)
        results = Array(results.prefix(truncateLength))
        let searchEngineMax = 8 - results.count - (hasCreateCard ? 1 : 0)
        results.append(contentsOf: searchEngineResults.prefix(searchEngineMax))

        results = self.autocompleteResultsUniqueUrls(sequence: results)

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
        return sequence.filter { seenUrl.update(with: $0.url?.absoluteString ?? $0.text) == nil }
    }
}
