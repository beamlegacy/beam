//
//  ClosedTabDataPersistence.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/11/2021.
//

import Foundation

class ClosedTabDataPersistence {
    static let closeTabCmdGrp = "CloseTabCmdGrp"

    private static let savedCloseTabCmdsKey = "savedClosedTabCmds"
    private static let savedTabsKey = "savedTabsKey"

    @UserDefault(key: savedCloseTabCmdsKey, defaultValue: Data(), suiteName: BeamUserDefaults.savedClosedTabs.suiteName)
    static var savedCloseTabData: Data

    @UserDefault(key: savedTabsKey, defaultValue: Data(), suiteName: BeamUserDefaults.savedClosedTabs.suiteName)
    static var savedTabsData: Data

}
