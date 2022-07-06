//
//  AnalyticsCollector.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 20/05/2022.
//
import Firebase
import BeamCore
import Foundation
import Combine

struct FirebaseMetrics {
    enum Omnibox: String {
        case queryLength = "omnibox_query_length"
        case chosenItemPosition = "omnibox_chosen_item_position"
        case exitState = "omnibox_exit_state"
        case resultCount = "omnibox_result_count"
    }
}
enum AnalyticsUserProperties: String {
    case branchType = "application_branch_type"
}

enum AnalyticsEventType: String {
    case omniboxQuery = "omnibox_query"
}

enum AnalyticsBackendType {
    case inMemory
    case firebase
}

protocol AnalyticsBackend {
    var type: AnalyticsBackendType { get }
    func send(event: AnalyticsEvent)
    func setUserProperty(property: AnalyticsUserProperties, value: String?)
}

extension AnalyticsBackend {
    func setUserPropertiesAtLaunch() {
        setUserProperty(property: AnalyticsUserProperties.branchType, value: Configuration.branchType?.rawValue)
    }
}
protocol AnalyticsEvent {
    var type: AnalyticsEventType { get }
    var firebaseEventParameters: [String: Any] { get }
}

enum OmniboxExitState: Equatable {

    case autocompleteResult(source: AutocompleteResult.Source)
    case aborted
    case searchQuery
    case url

    var shortDescription: String {
        switch self {
        case let .autocompleteResult(source: source): return "autocomplete_\(source.shortDescription)"
        case .aborted: return "aborted"
        case .url: return "url"
        case .searchQuery: return "search_query"
        }
    }
}

struct OmniboxQueryAnalyticsEvent: AnalyticsEvent {
    let type: AnalyticsEventType = .omniboxQuery
    var queryLength: Int = 0
    var chosenItemPosition: Int?
    var resultCount: Int = 0
    var exitState: OmniboxExitState = .aborted
    var firebaseEventParameters: [String: Any] {
        [
            FirebaseMetrics.Omnibox.queryLength.rawValue: queryLength,
            FirebaseMetrics.Omnibox.chosenItemPosition.rawValue: chosenItemPosition ?? -1,
            FirebaseMetrics.Omnibox.resultCount.rawValue: resultCount,
            FirebaseMetrics.Omnibox.exitState.rawValue: exitState.shortDescription
        ]
    }
}

class InMemoryAnalyticsBackend: AnalyticsBackend {
    let type: AnalyticsBackendType = .inMemory
    var userProperties = [AnalyticsUserProperties: String]()
    var events = [AnalyticsEvent]()
    func send(event: AnalyticsEvent) {
        events.append(event)
    }
    func setUserProperty(property: AnalyticsUserProperties, value: String?) {
        if let value = value {
            userProperties[property] = value
        } else {
            userProperties.removeValue(forKey: property)
        }
    }
    init() {
        setUserPropertiesAtLaunch()
    }
}

class FirebaseAnalyticsBackend: AnalyticsBackend {
    let type: AnalyticsBackendType = .firebase
    func send(event: AnalyticsEvent) {
        Analytics.logEvent(event.type.rawValue, parameters: event.firebaseEventParameters)
    }
    func setUserProperty(property: AnalyticsUserProperties, value: String?) {
        Analytics.setUserProperty(value, forName: property.rawValue)
    }
    var cancelable: Cancellable?

    private func delaySetUserPropertiesAtLaunch() {
        if !ThirdPartyLibrariesManager.shared.firebaseReady {
            cancelable = ThirdPartyLibrariesManager.shared.$firebaseReady.sink { ready in
                if ready {
                    self.setUserPropertiesAtLaunch()
                    self.cancelable?.cancel()
                }
            }
        } else { setUserPropertiesAtLaunch() }
    }
    init() {
        delaySetUserPropertiesAtLaunch()
    }
}

class AnalyticsCollector {
    var backends = [AnalyticsBackendType: AnalyticsBackend]()

    func add(backend: AnalyticsBackend) {
        backends[backend.type] = backend
    }
    func removeBackend(type: AnalyticsBackendType) {
        backends[type] = nil
    }

    func record(event: AnalyticsEvent) {
        for backend in backends.values {
            backend.send(event: event)
        }
    }
}
