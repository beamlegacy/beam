//
//  TabGroupingWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 22/05/2021.
//

import Foundation
import Cocoa
import Combine
import Clustering

class TabGroupingWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect, data: BeamData) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Tab Grouping"
        let tabGroupingContentView = TabGroupingContentView(clusteringManager: data.clusteringManager)

        contentView = BeamHostingView(rootView: tabGroupingContentView)
        isMovableByWindowBackground = false
        delegate = self
    }

    deinit {
        AppDelegate.main.tabGroupingWindow = nil
    }
}
