//
//  DataTree.swift
//  Beam
//
//  Created by Sebastien Metrot on 08/06/2022.
//

import Foundation
import SwiftUI
import AppKit
import Combine

class DataTreeWindow: NSWindow, NSWindowDelegate {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Data Tree"

        let dataTreeView = DataTreeView(treeRoot: AccountTreeNode(parent: nil, AppData.shared.currentAccount!))
        contentView = BeamHostingView(rootView: dataTreeView)
        isMovableByWindowBackground = false
        delegate = self
    }

    deinit {
        AppDelegate.main.dataTreeWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        cancellables.removeAll()
    }

    private var cancellables: [AnyCancellable] = []
    private func observeCoredataDestroyedNotification() {
        NotificationCenter.default
            .publisher(for: .coredataDestroyed, object: nil)
            .sink { _ in
                self.contentView = BeamHostingView(rootView: FilesContentView())
            }
            .store(in: &cancellables)
    }
}
