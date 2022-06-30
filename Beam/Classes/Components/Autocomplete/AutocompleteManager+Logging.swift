//
//  AutocompleteManager+Analytics.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/05/2022.
//

import Foundation
import BeamCore

// MARK: - Logging
extension AutocompleteManager {
    func logAutocompleteResultStarted(for searchText: String) {
        Logger.shared.logInfo("------------------- ✳️ Start of autocomplete for \(searchText) -------------------", category: .autocompleteManager)
    }

    func logAutocompleteResultFinished(for searchText: String, finalResults: [AutocompleteResult], startedAt: DispatchTime) {
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
}

// MARK: - Analytics
extension AutocompleteManager {
    func resetAnalyticsEvent() {
        analyticsEvent = OmniboxQueryAnalyticsEvent()
    }

    func recordItemSelection(index: Int?, source: AutocompleteResult.Source) {
        analyticsEvent?.chosenItemPosition = index
        analyticsEvent?.exitState = .autocompleteResult(source: source)
    }

    func recordTypedQueryLength(_ length: Int) {
        analyticsEvent?.queryLength = length
    }

    func recordNoSelection(isSearch: Bool) {
        analyticsEvent?.exitState = isSearch ? .searchQuery : .url
    }

    func recordResultCount() {
        analyticsEvent?.resultCount = autocompleteResults.count
    }
}
