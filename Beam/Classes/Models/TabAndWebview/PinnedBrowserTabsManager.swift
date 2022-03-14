//
//  PinnedBrowserTabsManager.swift
//  Beam
//
//  Created by Remi Santos on 18/10/2021.
//

import Foundation
import BeamCore

class PinnedBrowserTabsManager {

    private struct PinnedTabInfo: Codable {
        var tabId: UUID = UUID()
        let url: URL
        let title: String
    }

    @UserDefault(key: "PinnedTabs", defaultValue: Data(), suiteName: BeamUserDefaults.pinnedBrowserTabs.suiteName)
    var pinnedTabsData: Data

    private var encoder: JSONEncoder {
        JSONEncoder()
    }
    private var decoder: BeamJSONDecoder {
        BeamJSONDecoder()
    }

    private func getPinnedTabsInfos() throws -> [PinnedTabInfo] {
        guard !pinnedTabsData.isEmpty else { return [] }
        return try decoder.decode([PinnedTabInfo].self, from: pinnedTabsData)
    }

    func getPinnedTabs() -> [BrowserTab] {
        var tabs = [BrowserTab]()
        do {
            let tabsInfo = try getPinnedTabsInfos()
            tabs = tabsInfo.map { info in
                BrowserTab(pinnedTabWithId: info.tabId, url: info.url, title: info.title)
            }
        } catch {
            Logger.shared.logError("Couldn't decode pinned tabs", category: .web)
        }
        return tabs
    }

    func savePinnedTabs(tabs: [BrowserTab]) {
        let encoder = encoder
        do {
            let currentInfos = try getPinnedTabsInfos()
            let newInfos: [PinnedTabInfo] = tabs.compactMap { tab in
                guard let url = tab.url else { return nil }
                return currentInfos.first { $0.tabId == tab.id } ?? PinnedTabInfo(tabId: tab.id, url: url, title: tab.title)
            }
            let data = try encoder.encode(newInfos)
            pinnedTabsData = data
        } catch {
            Logger.shared.logError("Couldn't encode pinned tabs", category: .web)
        }
    }
}
