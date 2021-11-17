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

    override func run(context: BeamState?) -> Bool {
        guard let context = context, let tab = self.tab else { return false }
        if tab.isPinned {
            context.browserTabsManager.unpinTab(tab)
        }

        if appIsClosing {
            tab.closeApp()
        } else {
            tab.closeTab()
        }
        tab.cancelObservers()

        if let i = context.browserTabsManager.tabs.firstIndex(of: tab) {
            self.tabIndex = i

            context.browserTabsManager.tabs.remove(at: i)
            context.browserTabsManager.removeTabFromGroup(tabId: tab.id)

            if context.browserTabsManager.currentTab === tab {
                let nextTabIndex = min(i, context.browserTabsManager.tabs.count - 1)
                if nextTabIndex >= 0 {
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
