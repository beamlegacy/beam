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
    let fileManager: BeamFileDBManager
    init(contentRect: NSRect, fileManager: BeamFileDBManager) {
        self.fileManager = fileManager
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
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.contentView = BeamHostingView(rootView: FilesContentView(fileManager: self.fileManager))
            }
            .store(in: &cancellables)
    }
}
