//
//  AppDelegate+TabGrouping.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/05/2021.
//

import Foundation
import BeamCore

extension AppDelegate {

    static private var lastTabGroupingFeedback: Date?
    static private let tabGroupingFeedbackInterval: TimeInterval = 3600

    func showTagGroupingFeedbackIfNeeded() {
        guard Configuration.branchType == .develop, PreferencesManager.showTabsColoring else { return }
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
        guard self.data.clusteringManager.tabGroupingUpdater.hasPagesGroup && windows.contains(where: { $0.state.browserTabsManager.tabs.count > 0}) else { return }
        tabGroupingFeedbackWindow?.close()
        showTabGroupingFeedbackWindow(self)
    }

    @IBAction func showTabGroupingWindow(_ sender: Any) {
        if let tabGroupingWindow = tabGroupingWindow {
            tabGroupingWindow.makeKeyAndOrderFront(window)
            return
        }
        let tabGroupingTitleBarView = TabGroupingSettingsTitleBarView(clusteringManager: self.data.clusteringManager)

        let accessoryHostingView = BeamHostingView(rootView: tabGroupingTitleBarView)
        accessoryHostingView.frame.size = accessoryHostingView.fittingSize

        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.view = accessoryHostingView

        tabGroupingWindow = TabGroupingSettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), clusteringManager: self.data.clusteringManager)
        tabGroupingWindow?.addTitlebarAccessoryViewController(titlebarAccessory)
        tabGroupingWindow?.center()
        tabGroupingWindow?.makeKeyAndOrderFront(window)
    }

    @IBAction func showTabGroupingFeedbackWindow(_ sender: Any) {
        Self.lastTabGroupingFeedback = BeamDate.now
        if let tabGroupingFeedbackWindow = tabGroupingFeedbackWindow {
            tabGroupingFeedbackWindow.makeKeyAndOrderFront(window)
            return
        }
        let newWindow = TabGroupingFeedbackWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), clusteringManager: self.data.clusteringManager)
        newWindow.center()
        newWindow.makeKeyAndOrderFront(window)
        tabGroupingFeedbackWindow = newWindow
    }
}
