//
//  AppDelegate+TabGrouping.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/05/2021.
//

import Foundation

extension AppDelegate {

    @IBAction func showTabGroupingWindow(_ sender: Any) {
        if let tabGroupingWindow = tabGroupingWindow {
            tabGroupingWindow.makeKeyAndOrderFront(window)
            return
        }
        let tabGroupingTitleBarView = TabGroupingTitleBarView(clusteringManager: self.data.clusteringManager)

        let accessoryHostingView = BeamHostingView(rootView: tabGroupingTitleBarView)
        accessoryHostingView.frame.size = accessoryHostingView.fittingSize

        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.view = accessoryHostingView

        tabGroupingWindow = TabGroupingWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), clusteringManager: self.data.clusteringManager)
        tabGroupingWindow?.addTitlebarAccessoryViewController(titlebarAccessory)
        tabGroupingWindow?.center()
        tabGroupingWindow?.makeKeyAndOrderFront(window)
    }

    @IBAction func showTabGroupingFeedbackWindow(_ sender: Any) {
        if let tabGroupingFeedbackWindow = tabGroupingFeedbackWindow {
            tabGroupingFeedbackWindow.makeKeyAndOrderFront(window)
            return
        }
        tabGroupingFeedbackWindow = TabGroupingFeedbackWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 599), clusteringManager: self.data.clusteringManager)
        tabGroupingFeedbackWindow?.center()
        tabGroupingFeedbackWindow?.makeKeyAndOrderFront(window)
    }
}
