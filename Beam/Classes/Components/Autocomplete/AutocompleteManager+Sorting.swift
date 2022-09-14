//
//  AutocompleteManager+Sorting.swift
//  Beam
//
//  Created by Remi Santos on 21/07/2021.
//

import Foundation

private struct ResultsToSort {
    let notesResults: [AutocompleteResult]
    let historyResults: [AutocompleteResult]
    let urlResults: [AutocompleteResult]
    let topDomainResults: [AutocompleteResult]
    let mnemonicResults: [AutocompleteResult]
    let openedTabResults: [AutocompleteResult]
    let tabGroupsResults: [AutocompleteResult]
    let searchEngineResults: [AutocompleteResult]
    let otherResults: [AutocompleteResult]
    let createCardResults: [AutocompleteResult]
}

extension AutocompleteManager {
    private static let resultsLimit = 8

    func mergeAndSortPublishersResults(publishersResults: [AutocompletePublisherSourceResults],
                                       for searchText: String, expectSearchEngineResultsLater: Bool = true, limit: Int? = nil) -> (results: [AutocompleteResult], canCreateNote: Bool) {
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
        let otherResults = autocompleteResults[.action] ?? []

        var defaultLimit = Self.resultsLimit
        if case .tabGroup = mode {
            defaultLimit = 40
        }
        let limit = limit ?? defaultLimit
        let resultsToSort = ResultsToSort(notesResults: autocompleteResults[.note, default: []],
                                          historyResults: autocompleteResults[.history] ?? [],
                                          urlResults: autocompleteResults[.url] ?? [],
                                          topDomainResults: autocompleteResults[.topDomain] ?? [],
                                          mnemonicResults: autocompleteResults[.mnemonic] ?? [],
                                          openedTabResults: autocompleteResults[.tab(tabId: nil)] ?? [],
                                          tabGroupsResults: autocompleteResults[.tabGroup(group: nil)] ?? [],
                                          searchEngineResults: autocompleteResults[.searchEngine] ?? [],
                                          otherResults: otherResults,
                                          createCardResults: autocompleteResults[.createNote] ?? [])
        let finalResults = sortResults(resultsToSort,
                                       expectSearchEngineResultsLater: expectSearchEngineResultsLater,
                                       limit: limit)

        let canCreateNote = autocompleteResults[.createNote]?.isEmpty == false
        return (results: finalResults, canCreateNote: canCreateNote)
    }

    private func sortResults(_ resultsToSort: ResultsToSort,
                             expectSearchEngineResultsLater: Bool,
                             limit: Int) -> [AutocompleteResult] {

        let start = DispatchTime.now()
        let historyResultsTruncated = Array(resultsToSort.historyResults.prefix(6))

        // but prioritize title match over content match ?
        let notesResultsTruncated = Array(autocompleteResultsUniqueNotes(sequence: resultsToSort.notesResults).prefix(6))
        let urlResultsTruncated = Array(resultsToSort.urlResults.prefix(6))

        var sortableResults = [AutocompleteResult]()
        let uniqueURLs = autocompleteResultsUniqueURLs(sequence: historyResultsTruncated + urlResultsTruncated)
        self.rawSortedURLResults = uniqueURLs
        let urlsAndOpenedTabs = autocompleteResultsURLResultsMixedWithOpenedTabs(urlResults: uniqueURLs, openedTabResults: resultsToSort.openedTabResults)
        sortableResults.append(contentsOf: urlsAndOpenedTabs)
        sortableResults.append(contentsOf: notesResultsTruncated)
        sortableResults.append(contentsOf: resultsToSort.tabGroupsResults)

        sortableResults.sort(by: >)
        Self.logIntermediate(step: "SortableResults", stepShortName: "SR", results: sortableResults, startedAt: start)

        sortableResults = boostResult(resultsToSort.topDomainResults, results: sortableResults)
        sortableResults = boostResult(resultsToSort.mnemonicResults, results: sortableResults)

        var filteredSearchEngineResults = filterOutSearchEngineURLResults(from: resultsToSort.searchEngineResults, forURLAlreadyIn: sortableResults)
        filteredSearchEngineResults = autocompleteResultsUniqueSearchEngine(sequence: filteredSearchEngineResults)

        let results = merge(sortableResults: sortableResults,
                            searchEngineResults: filteredSearchEngineResults,
                            otherResults: resultsToSort.otherResults,
                            createCardResults: resultsToSort.createCardResults,
                            limit: limit,
                            expectSearchEngineResultsLater: expectSearchEngineResultsLater)
        return results
    }

    /// Promote top domain result to the top if the current first result is not satisfying.
    private func boostResult(_ partialResults: [AutocompleteResult], results: [AutocompleteResult]) -> [AutocompleteResult] {
        guard let partialResult = partialResults.first else { return results }

        guard let firstResult = results.first,
              isResultCandidateForAutoselection(firstResult, forSearch: firstResult.completingText ?? "") ||
                results.contains(where: { $0.text == partialResult.text })
        else {
            return [partialResult] + results
        }

        return results
    }

    private func merge(sortableResults: [AutocompleteResult],
                       searchEngineResults: [AutocompleteResult],
                       otherResults: [AutocompleteResult],
                       createCardResults: [AutocompleteResult],
                       limit: Int,
                       expectSearchEngineResultsLater: Bool) -> [AutocompleteResult] {
        let hasCreateCard = !createCardResults.isEmpty
        var searchEngineSpace: Int = 0
        // leave space for at least 2 search engine result, even if they arrive later.
        if !searchEngineResults.isEmpty || expectSearchEngineResultsLater {
            searchEngineSpace = searchEngineResults.count > 0 ? min(2, searchEngineResults.count) : 2
        }
        let truncateLength = limit - searchEngineSpace - (hasCreateCard ? 1 : 0) - otherResults.count

        var results = truncateSortablesKeepingImportantNotes(sortableResults, limit: truncateLength)

        let searchEngineMax = truncateLength - results.count + searchEngineSpace
        results.insert(contentsOf: searchEngineResults.prefix(searchEngineMax), at: sortableResults.isEmpty ? 0 : 1)
        results.append(contentsOf: otherResults)
        if case .noteCreation = mode {
            results.insert(contentsOf: createCardResults, at: 0)
        } else {
            results.append(contentsOf: createCardResults)
        }
        return results
    }

    /// We need to make sure notes with matching are not discarded even though their score is low
    private func truncateSortablesKeepingImportantNotes(_ results: [AutocompleteResult], limit: Int) -> [AutocompleteResult] {

        var truncated = Array(results.prefix(limit))
        guard results.count > limit else { return truncated }

        let containsNotes = truncated.contains { result in
            guard case .note = result.source else { return false }
            return true
        }
        guard !containsNotes else { return truncated }

        let leftovers = Array(results.suffix(from: limit))
        let leftOverNotes = leftovers.filter { r in
            guard case .note = r.source else { return false }
            return r.prefixScore > 1.0
        }
        guard !leftOverNotes.isEmpty else { return truncated }
        let minimumNumberOfNotes = Int(Double(limit) * 0.4) // 40% ex: 2 out of 6 results should be notes
        let notesToAdd = leftOverNotes.prefix(minimumNumberOfNotes)
        truncated.removeLast(notesToAdd.count)
        truncated.append(contentsOf: notesToAdd)
        return truncated
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
        } else if let selectedIndex = autocompleteSelectedIndex {
            insertionIndex = selectedIndex + 1
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
            } else if let aliasId = result.aliasForDestinationURL?.urlStringByRemovingUnnecessaryCharacters, uniqueURLs[aliasId] != nil {
                // Don't insert aliases if their destination is already here
                continue
            } else {
                uniqueURLs[id] = finalList.count
                finalList.append(result)
            }
        }
        return finalList.sorted(by: >)
    }

    /// Replace url results by their opened tab equivalent, while keeping the highest score.
    private func autocompleteResultsURLResultsMixedWithOpenedTabs(urlResults: [AutocompleteResult], openedTabResults: [AutocompleteResult]) -> [AutocompleteResult] {
        var final = [AutocompleteResult]()
        var unusedOpenedTabs = openedTabResults
        urlResults.forEach { urlResult in
            if let openedTabIndex = unusedOpenedTabs.firstIndex(where: {
                $0.url?.urlStringByRemovingUnnecessaryCharacters == urlResult.url?.urlStringByRemovingUnnecessaryCharacters                
            }) {
                let openedTabResult = unusedOpenedTabs[openedTabIndex]
                let copied = copyURLResultForOpenedTab(urlResult, openedTabResult: openedTabResult)
                final.append(copied)
                unusedOpenedTabs.remove(at: openedTabIndex)
            } else {
                final.append(urlResult)
            }
        }
        final.append(contentsOf: unusedOpenedTabs)
        return final
    }

    private func copyURLResultForOpenedTab(_ urlResult: AutocompleteResult, openedTabResult: AutocompleteResult) -> AutocompleteResult {
        let u = urlResult
        let score = max(u.score ?? 0, openedTabResult.score ?? 0)
        return AutocompleteResult(text: u.text, source: openedTabResult.source, disabled: u.disabled,
                                  url: u.url, aliasForDestinationURL: u.aliasForDestinationURL,
                                  information: u.information, customIcon: u.icon, iconColor: u.iconColor,
                                  shortcut: openedTabResult.shortcut, completingText: u.completingText, additionalSearchTerms: u.additionalSearchTerms,
                                  uuid: u.uuid, score: score, urlFields: u.urlFields, displayTopDivider: u.shouldDisplayTopDivider, handler: openedTabResult.handler)
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
