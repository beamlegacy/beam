//
//  ContentBlockingManager.swift
//  Beam
//
//  Created by Nicolas Lapomarda on 03/02/2021.
//

import Foundation
import Combine
import BeamCore

extension Filter.Group {
    var ruleStoreIdentifier: String {
        return self.name
    }
}

class ContentBlockingManager {
    static let shared = ContentBlockingManager()

    private let listStore: WKContentRuleListStore
    private var ruleLists = [String: WKContentRuleList]()

    let radBlockPreferences: RadBlockPreferencesManager
    init() {
        self.listStore = WKContentRuleListStore.default()
        self.radBlockPreferences = RadBlockPreferencesManager()
    }

    func setup() {
        // Setup Hush
        if let hushURL = Bundle.main.url(forResource: "hush", withExtension: "json") {
            loadRules("hush", hushURL)
        }

        // Setup RadBlock
        synchronize()
    }

    func synchronize() {
        FilterManager.default.synchronize(with: .rescheduleOnError) { [weak self] (error) in
            if let error = error {
                Logger.shared.logError("Sync error: \(error.localizedDescription)", category: .contentBlocking)
                return
            }

            let state = FilterManager.default.state
            let groups = state.filterGroups
            let allowList = RadBlockDatabase.shared
            let blockers = groups.map { RBContentBlocker(filterGroup: $0, allowList: allowList) }
            self?.compileLists(blockers: blockers)
            Logger.shared.logInfo("Radblock filters are synchronized", category: .contentBlocking)
        }
    }

    func removeAllRulesLists() {
        self.ruleLists.removeAll()
    }

    func configure(webView: WKWebView) {
        let configuration = webView.configuration.userContentController
        configuration.removeAllContentRuleLists()
        ruleLists.values.forEach(configuration.add)
        Logger.shared.logInfo("Added \(ruleLists.count) rule lists", category: .contentBlocking)
    }

    private func loadBlocker(_ blocker: RBContentBlocker) {
        loadRules(blocker.filterGroup.ruleStoreIdentifier, blocker.rulesFileURL)
    }

    private func loadRules(_ identifier: String, _ url: URL) {
        if let contents = try? String(contentsOf: url) {
            listStore.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: contents) { [weak self] (ruleList, error) in
                if let error = error {
                    Logger.shared.logError("Rule compilation error for \(identifier): \(error.localizedDescription)", category: .contentBlocking)
                }
                self?.register(ruleList: ruleList, identifier: identifier)
            }
        } else {
            Logger.shared.logError("Failed to load contents at \(url)", category: .contentBlocking)
        }
    }

    private func compileLists(blockers: [RBContentBlocker]) {
        blockers.forEach { blocker in
            blocker.writeRules { _, _ in
                self.loadBlocker(blocker)
            }
        }
    }

    private func register(ruleList: WKContentRuleList?, identifier: String) {
        if let ruleList = ruleList, (identifier == "hush" || identifier == "regional") {
            add(ruleList: ruleList, identifier: identifier)
        }
        if radBlockPreferences.isAdsFilterEnabled && identifier == "ads" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !radBlockPreferences.isAdsFilterEnabled && identifier == "ads" {
            remove(ruleList: ruleList, identifier: identifier)
        }
        if radBlockPreferences.isAnnoyancesFilterEnabled && identifier == "annoyance" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !radBlockPreferences.isAnnoyancesFilterEnabled && identifier == "annoyance" {
            remove(ruleList: ruleList, identifier: identifier)
        }
        if radBlockPreferences.isPrivacyFilterEnabled && identifier == "privacy" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !radBlockPreferences.isPrivacyFilterEnabled && identifier == "privacy" {
            remove(ruleList: ruleList, identifier: identifier)
        }
    }

    private func add(ruleList: WKContentRuleList?, identifier: String) {
        Logger.shared.logInfo("Radblock register rulist for \(identifier)", category: .contentBlocking)
        ruleLists[identifier] = ruleList
    }

    private func remove(ruleList: WKContentRuleList?, identifier: String) {
        Logger.shared.logInfo("Radblock removed rulist for \(identifier)", category: .contentBlocking)
        ruleLists.removeValue(forKey: identifier)
    }
}

extension ContentBlockingManager {
    public func hasDomainInAllowList(domain: String, completion: @escaping (Bool) -> Void) {
        RadBlockDatabase.shared.allowlistEntry(forDomain: domain) { entry, _ in
            completion(entry != nil)
        }
    }
}
