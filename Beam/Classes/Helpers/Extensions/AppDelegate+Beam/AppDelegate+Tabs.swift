//
//  AppDelegate+TabGrouping.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/05/2021.
//

import Foundation
import BeamCore


// MARK: - Tabs Retrieval
extension AppDelegate {

    func windowContainingTab(_ tabId: BrowserTab.TabID) -> BeamWindow? {
        return windows.first(where: {
            window in window.state.browserTabsManager.tabs.contains(where: { $0.id == tabId })
        })
    }
}

// MARK: - Tab Grouping Feedback
extension AppDelegate {

    static private var lastTabGroupingFeedback: Date?
    static private let tabGroupingFeedbackInterval: TimeInterval = 3600

    func showTagGroupingFeedbackIfNeeded() {
        guard PreferencesManager.enableTabGroupingFeedback else { return }
        guard let lastTabGroupingFeedback = Self.lastTabGroupingFeedback else {
            Self.lastTabGroupingFeedback = BeamDate.now
            return
        }
        if lastTabGroupingFeedback.timeIntervalSinceNow < -Self.tabGroupingFeedbackInterval {
            autoShowTabGroupingFeedbackWindow()
        }
    }

    private func autoShowTabGroupingFeedbackWindow() {
        Self.lastTabGroupingFeedback = BeamDate.now
        guard self.data.currentAccount?.data.clusteringManager.tabGroupingManager?.hasPagesGroup == true && windows.contains(where: { $0.state.browserTabsManager.tabs.count > 0}) else { return }
        tabGroupingFeedbackWindow?.close()
        showTabGroupingFeedbackWindow(self)
    }

    @IBAction func showTabGroupingWindow(_ sender: Any) {
        if let tabGroupingWindow = tabClusterinV1SettingsWindow {
            tabGroupingWindow.makeKeyAndOrderFront(window)
            return
        }
        guard let windowData = data.currentAccount?.data else {
            return
        }
        let tabGroupingTitleBarView = TabGroupingSettingsTitleBarView(clusteringManager: windowData.clusteringManager)

        let accessoryHostingView = BeamHostingView(rootView: tabGroupingTitleBarView)
        accessoryHostingView.frame.size = accessoryHostingView.fittingSize

        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.view = accessoryHostingView

        tabClusterinV1SettingsWindow = TabClusteringV1SettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), data: windowData)
        tabClusterinV1SettingsWindow?.addTitlebarAccessoryViewController(titlebarAccessory)
        tabClusterinV1SettingsWindow?.center()
        tabClusterinV1SettingsWindow?.makeKeyAndOrderFront(window)
    }

    @IBAction func showTabGroupingFeedbackWindow(_ sender: Any) {
        Self.lastTabGroupingFeedback = BeamDate.now
        if let tabGroupingFeedbackWindow = tabGroupingFeedbackWindow {
            tabGroupingFeedbackWindow.makeKeyAndOrderFront(window)
            return
        }
        guard let windowData = data.currentAccount?.data else {
            return
        }
        let newWindow = TabGroupingFeedbackWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), data: windowData)
        newWindow.center()
        newWindow.makeKeyAndOrderFront(window)
        tabGroupingFeedbackWindow = newWindow
    }
}
