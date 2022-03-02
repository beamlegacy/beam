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
        let configuration = webView.configurationWithoutMakingCopy
        let userContentController = configuration.userContentController
        userContentController.removeAllContentRuleLists()
        ruleLists.values.forEach(userContentController.add)
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
        if PreferencesManager.isAdsFilterEnabled && identifier == "ads" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !PreferencesManager.isAdsFilterEnabled && identifier == "ads" {
            remove(ruleList: ruleList, identifier: identifier)
        }
        if PreferencesManager.isAdsFilterEnabled && identifier == "regional" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !PreferencesManager.isAdsFilterEnabled && identifier == "regional" {
            remove(ruleList: ruleList, identifier: identifier)
        }
        if PreferencesManager.isAnnoyancesFilterEnabled && identifier == "annoyance" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !PreferencesManager.isAnnoyancesFilterEnabled && identifier == "annoyance" {
            remove(ruleList: ruleList, identifier: identifier)
        }
        if PreferencesManager.isPrivacyFilterEnabled && identifier == "privacy" {
            add(ruleList: ruleList, identifier: identifier)
        } else if !PreferencesManager.isPrivacyFilterEnabled && identifier == "privacy" {
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

    func authorizeJustOnce(for webView: WKWebView, domain: String, completion: @escaping () -> Void) {
        Logger.shared.logInfo("Radblock register temporary rulist for \(domain)", category: .contentBlocking)
        let jsonRuleList = """
        [
            {
                "trigger": { "url-filter": "\(domain)" },
                "action": { "type": "ignore-previous-rules" }
            }
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "tmpAllowList", encodedContentRuleList: jsonRuleList) { [synchronize] list, _
            in
            guard let list = list else { return }

            // Add the stylesheet-blocker to your webview's configuration
            let configuration = webView.configuration.userContentController
            configuration.removeAllContentRuleLists()
            configuration.add(list)
            synchronize()
            completion()
        }
    }
}
