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
        self.data.clusteringManager = ClusteringManager()
        guard let clusteringManager = self.data.clusteringManager else { return }
        let tabGroupingTitleBarView = TabGroupingTitleBarView(clusteringManager: clusteringManager)

        let accessoryHostingView = BeamHostingView(rootView: tabGroupingTitleBarView)
        accessoryHostingView.frame.size = accessoryHostingView.fittingSize

        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.view = accessoryHostingView

        tabGroupingWindow = TabGroupingWindow(contentRect: NSRect(x: 0, y: 0, width: 518, height: 350), clusteringManager: clusteringManager)
        tabGroupingWindow?.addTitlebarAccessoryViewController(titlebarAccessory)
        tabGroupingWindow?.center()
        tabGroupingWindow?.makeKeyAndOrderFront(window)
    }
}
