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
    var group: TabGroup?

    enum CodingKeys: String, CodingKey {
        case tab
        case tabData
        case tabIndex
        case wasCurrentTab
        case group
    }

    init(tab: BrowserTab, appIsClosing: Bool = false, tabIndex: Int, wasCurrentTab: Bool, group: TabGroup? = nil) {
        self.tab = tab
        self.appIsClosing = appIsClosing
        self.tabIndex = tabIndex
        self.wasCurrentTab = wasCurrentTab
        self.group = group

        super.init(name: Self.name)
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tab = try values.decode(BrowserTab.self, forKey: .tab)
        tabIndex = try values.decode(Int.self, forKey: .tabIndex)

        try super.init(from: decoder)

        tabData = try values.decode(Data.self, forKey: .tabData)
        wasCurrentTab = try values.decode(Bool.self, forKey: .wasCurrentTab)
        group = try? values.decode(TabGroup.self, forKey: .group)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tab, forKey: .tab)
        try container.encode(tabData, forKey: .tabData)
        try container.encode(tabIndex, forKey: .tabIndex)
        try container.encode(wasCurrentTab, forKey: .wasCurrentTab)
        try? container.encode(group, forKey: .group)
    }

    override func run(context: BeamState?) -> Bool {
        guard let context = context, let tab = self.tab else { return false }

        if !appIsClosing {
            tab.tabWillClose()
        }

        tabData = encode(tab: tab)

        if tab.isPinned {
            context.browserTabsManager.unpinTab(tab)
        }

        if let i = context.browserTabsManager.tabs.firstIndex(of: tab) {
            self.tabIndex = i
            wasCurrentTab = context.browserTabsManager.currentTab === tab
            context.browserTabsManager.removeTab(tabId: tab.id)
        }
        context.browserTabsManager.resetFirstResponderAfterClosingTab()
        return true
    }

    override func undo(context: BeamState?) -> Bool {
        guard let context = context,
              let data = self.tabData,
              let tab = decode(data: data) else { return false }

        let tabsManager = context.browserTabsManager
        if tabsManager.tabs.contains(where: { $0.id == tab.id && $0.url == tab.preloadUrl }) {
            // Doesn't needs to be undone since it's already existing
            return true
        }

        var urlRequest: URLRequest?
        if let url = tab.url {
            urlRequest = URLRequest(url: url)
        }

        tabsManager.addNewTabAndNeighborhood(
            tab,
            setCurrent: wasCurrentTab,
            withURLRequest: urlRequest,
            at: tabIndex
        )

        if tab.isPinned {
            tabsManager.pinTab(tab)
        }
        if !wasCurrentTab {
            tab.postLoadSetup(state: context)
        }
        if var group = group {
            group = tabsManager.tabGroupingManager.existingGroup(forGroupID: group.id) ?? group
            tabsManager.moveTabToGroup(tab.id, group: group)
        }
        self.tab = tab
        return true
    }

    override func coalesce(command: Command<BeamState>) -> Bool {
        return false
    }
}
