//
//  WebContentDeletionManager.swift
//  Beam
//
//  Created by Remi Santos on 19/09/2022.
//

import Foundation
import BeamCore
import SwiftUI

struct WebContentDeletionManager {

    let accountData: BeamData

    enum HistoryInterval: CaseIterable {
        case hour, day, month, all

        var longLocalizedDescription: LocalizedStringKey {
            switch self {
            case .hour: return "the last hour"
            case .day: return "the last day"
            case .month: return "the last month"
            case .all: return "everything"
            }
        }

        /// Return the date by removing the interval to now.
        var referenceDateFromNow: Date? {
            let calendar = Calendar.current
            switch self {
            case .hour:
                return calendar.date(byAdding: DateComponents(hour: -1), to: BeamDate.now)
            case .day:
                return calendar.date(byAdding: DateComponents(day: -1), to: BeamDate.now)
            case .month:
                return calendar.date(byAdding: DateComponents(month: -1), to: BeamDate.now)
            case .all:
                return nil
            }
        }
    }

    /// Clears the Link database and all the siblings such as Indexes, BrowsingTrees, Mnemonic, etc.
    func clearHistory(_ interval: HistoryInterval = .all) throws {
        let date: Date? = interval.referenceDateFromNow

        let browsingTreeManager = accountData.browsingTreeDBManager
        let pinSuggester = accountData.tabPinSuggestionDBManager
        let mnemonicManager = accountData.mnemonicManager
        let linksDBManager = accountData.linksDBManager

        // Browsing Tree
        try browsingTreeManager?.deleteBrowsingTrees(createdAfter: date)

        // Tab Pin suggester
        try pinSuggester?.cleanTabPinSuggestions(afterDate: date)

        // dailyURLScore
        GRDBDailyUrlScoreStore().cleanup(afterDate: date)
        let links = try accountData.linkDB.allObjects(updatedSince: date)
        let linksIds = links.map { $0.id }

        // mnemonic
        try mnemonicManager?.deleteAll(forLinks: linksIds)
        // url + frecencyUrlRecord
        try linksDBManager?.softDeleteAll(links.map { $0.id })
    }

    /// Clears webkit content and favicon cache
    func clearWebCaches(_ interval: HistoryInterval = .all) {
        AppData.shared.accounts.forEach {
            $0.data.faviconProvider.clearCache()
        }
        let date = interval.referenceDateFromNow ?? Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
                                                modifiedSince: date, completionHandler: { })
    }
}
