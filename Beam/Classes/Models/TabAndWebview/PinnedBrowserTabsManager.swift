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

    private static var PinnedTabsUserDefaultsKey: String {
        #if TEST || DEBUG
            return "PinnedTabsDebug"
        #else
            return "PinnedTabs"
        #endif
    }

    private var encoder: JSONEncoder {
        JSONEncoder()
    }
    private var decoder: JSONDecoder {
        JSONDecoder()
    }

    private func getPinnedTabsInfos() throws -> [PinnedTabInfo] {
        guard let data = UserDefaults.standard.value(forKey: Self.PinnedTabsUserDefaultsKey) as? Data else { return [] }
        return try decoder.decode([PinnedTabInfo].self, from: data)
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
            UserDefaults.standard.set(data, forKey: Self.PinnedTabsUserDefaultsKey)
        } catch {
            Logger.shared.logError("Couldn't encode pinned tabs", category: .web)
        }
    }
}
