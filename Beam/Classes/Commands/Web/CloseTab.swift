//
//  CloseTab.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 25/08/2021.
//

import Foundation
import BeamCore

class CloseTab: WebCommand {
    static let name: String = "CloseTab"

    weak var tab: BrowserTab?
    var tabData: Data?
    var tabIndex: Int
    var appIsClosing: Bool = false
    var wasCurrentTab: Bool = false

    enum CodingKeys: String, CodingKey {
        case tab
        case tabData
        case tabIndex
        case wasCurrentTab
    }

    init(tab: BrowserTab, appIsClosing: Bool = false, tabIndex: Int, wasCurrentTab: Bool) {
        self.tab = tab
        self.appIsClosing = appIsClosing
        self.tabIndex = tabIndex
        self.wasCurrentTab = wasCurrentTab

        super.init(name: Self.name)
        self.tabData = encode(tab: tab)
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tab = try values.decode(BrowserTab.self, forKey: .tab)
        tabIndex = try values.decode(Int.self, forKey: .tabIndex)

        try super.init(from: decoder)

        tabData = try values.decode(Data.self, forKey: .tabData)
        wasCurrentTab = try values.decode(Bool.self, forKey: .wasCurrentTab)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tab, forKey: .tab)
        try container.encode(tabData, forKey: .tabData)
        try container.encode(tabIndex, forKey: .tabIndex)
        try container.encode(wasCurrentTab, forKey: .wasCurrentTab)
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func run(context: BeamState?) -> Bool {
        guard let context = context, let tab = self.tab else { return false }
        if tab.isPinned {
            context.browserTabsManager.unpinTab(tab)
        }

        if !appIsClosing {
            tab.closeTab()
        }
        tab.cancelObservers()

        if let i = context.browserTabsManager.tabs.firstIndex(of: tab) {
            self.tabIndex = i

            var tabParentToGo: BrowserTab?
            switch tab.browsingTreeOrigin {
            case .browsingNode(_, _, _, let rootId):
                // If user cmd+click from a tab we want to go back to this tab
                tabParentToGo = context.browserTabsManager.tabs.first(where: {$0.browsingTree.rootId == rootId})
            case .searchBar(_, referringRootId: let referringRootId):
                // If user cmd+T from a current tab we want to comeback to that origin tab
                tabParentToGo = context.browserTabsManager.tabs.first(where: {$0.browsingTree.rootId == referringRootId})
            default: break
            }

            context.browserTabsManager.tabs.remove(at: i)
            let nextTabIdFromGroup = context.browserTabsManager.removeFromTabGroup(tabId: tab.id)
            let nextTabIndex = min(i, context.browserTabsManager.tabs.count - 1)

            if context.browserTabsManager.currentTab === tab {
                if let tabParentToGo = tabParentToGo, nextTabIdFromGroup == nil {
                    context.browserTabsManager.currentTab = tabParentToGo
                } else if let nextTabIdFromGroup = nextTabIdFromGroup {
                    context.browserTabsManager.currentTab = context.browserTabsManager.tabs.first(where: {$0.id == nextTabIdFromGroup})
                } else if nextTabIndex >= 0 {
                    context.browserTabsManager.currentTab = context.browserTabsManager.tabs[nextTabIndex]
                } else {
                    context.browserTabsManager.currentTab = nil
                }
                wasCurrentTab = true
            }
        }
        context.browserTabsManager.resetFirstResponderAfterClosingTab()
        return true
    }

    override func undo(context: BeamState?) -> Bool {
        guard let context = context,
              let data = self.tabData,
              let tab = decode(data: data) else { return false }

        if context.browserTabsManager.tabs.contains(where: { $0.id == tab.id && $0.url == tab.preloadUrl }) {
            // Doesn't needs to be undone since it's already existing
            return true
        }
        context.browserTabsManager.addNewTabAndGroup(tab, setCurrent: wasCurrentTab, withURL: tab.url, at: tabIndex)
        if tab.isPinned {
            context.browserTabsManager.pinTab(tab)
        }
        if !wasCurrentTab {
            tab.postLoadSetup(state: context)
        }
        self.tab = tab
        return true
    }

    override func coalesce(command: Command<BeamState>) -> Bool {
        return false
    }
}
