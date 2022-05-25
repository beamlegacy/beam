//
//  AutocompleteManager+Analytics.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 23/05/2022.
//

import Foundation

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
