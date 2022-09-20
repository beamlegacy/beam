//
//  TabClusteringV1SettingsWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/05/2021.
//

import Foundation
import Cocoa
import Combine
import Clustering

class TabClusteringV1SettingsWindow: NSWindow, NSWindowDelegate {

    init(contentRect: NSRect, data: BeamData) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Tab Grouping"

        let tabGroupingContentView = TabGroupingSettingsContentView(clusteringManager: data.clusteringManager)
            .faviconProvider(data.faviconProvider)

        contentView = BeamHostingView(rootView: tabGroupingContentView)
        isMovableByWindowBackground = false
        delegate = self
    }

    deinit {
        AppDelegate.main.tabClusterinV1SettingsWindow = nil
    }
}
