//
//  TabGroupExternalDraggingSource.swift
//  Beam
//
//  Created by Remi Santos on 25/07/2022.
//

import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static let beamTabGroup = UTType("co.beamapp.tabgroup") ?? .data
}

extension NSPasteboard.PasteboardType {
    static let beamTabGroup = NSPasteboard.PasteboardType(UTType.beamTabGroup.description)
}

private class TabGroupPasteboardProvider: NSObject, NSPasteboardItemDataProvider {
    private weak var tabGroup: TabGroup?

    init(with tabGroup: TabGroup) {
        self.tabGroup = tabGroup
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard type == .beamTabGroup, let tabGroup = tabGroup else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(tabGroup) {
            pasteboard?.setData(data, forType: .beamTabGroup)
        }
    }

    func pasteboardFinishedWithDataProvider(_ pasteboard: NSPasteboard) { }
}

/// Simple Tab View used to render the dragging session image
private struct TabGroupViewForSnapshot: View {
    var group: TabGroup
    var title: String
    var size: CGSize
    var body: some View {
        TabClusteringGroupCapsuleView(displayedText: title,
                                      color: group.color ?? .init(designColor: .red),
                                      collapsed: group.collapsed, itemsCount: group.pageIds.count)
        .frame(width: size.width, height: size.height)
    }
}

protocol TabGroupExternalDraggingSourceDelegate: AnyObject {
    func tabGroupExternalDragSessionEnded()
}

final class TabGroupExternalDraggingSource: NSObject {

    private weak var state: BeamState?
    private weak var delegate: TabGroupExternalDraggingSourceDelegate?
    private var tabGroup: TabGroup?
    private var title: String?
    private(set) var itemSize: CGSize = CGSize(width: 100, height: TabView.height)
    private var tabs: [BrowserTab]?

    private var draggingImage: NSImage?
    private var transparentDraggingImage: NSImage?

    init(state: BeamState, delegate: TabGroupExternalDraggingSourceDelegate) {
        self.state = state
        self.delegate = delegate
        super.init()
    }

    private func draggingItemFrame(location: CGPoint, convertToWindow window: NSWindow?) -> CGRect {
        var point = location
        if let window = window {
            point = location.flippedPointToBottomLeftOrigin(in: window)
        }
        let size = itemSize
        return CGRect(x: point.x, y: point.y - size.height/2,
                      width: size.width, height: size.height)
    }

    func startDraggingItem(for tabGroup: TabGroup, tabs: [BrowserTab], location: CGPoint, size: CGSize, title: String) -> NSDraggingItem {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(TabGroupPasteboardProvider(with: tabGroup), forTypes: [.beamTabGroup])

        let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        self.itemSize = size
        let itemFrame = draggingItemFrame(location: location, convertToWindow: state?.associatedWindow)
        let view = TabGroupViewForSnapshot(group: tabGroup, title: title, size: itemFrame.size)
        self.draggingImage = view.snapshot()
        self.tabGroup = tabGroup
        self.title = title
        self.tabs = tabs
        return dragItem
    }

    func endDraggingItem() { }

    func updateInitialDragginItemLocation(_ dragItem: NSDraggingItem, location: CGPoint) {
        let itemFrame = draggingItemFrame(location: location, convertToWindow: state?.associatedWindow)
        dragItem.setDraggingFrame(itemFrame, contents: self.draggingImage)
    }

    func finishDropping(in destinationState: BeamState?, insertIndex: Int) {
        guard let group = self.tabGroup else { return }
        tabs?.reversed().forEach {
            destinationState?.browserTabsManager.addNewTabAndNeighborhood($0, setCurrent: false, at: insertIndex)
        }
        destinationState?.openTabGroup(group)
        tabGroup = nil
        tabs = nil
    }
}

extension TabGroupExternalDraggingSource: ExternalDraggingSource {

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) { }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) { }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.endDraggingItem()
        let isHandledByBeamUI = state?.data.currentDraggingSession?.dropHandledByBeamUI ?? false
        state?.data.currentDraggingSession = nil
        delegate?.tabGroupExternalDragSessionEnded()

        guard tabGroup != nil && !isHandledByBeamUI else {
            if state?.associatedWindow?.isVisible == false && state?.browserTabsManager.tabs.filter({ !$0.isPinned }).isEmpty == true {
                state?.associatedWindow?.close()
            }
            return
        }

        if state?.browserTabsManager.tabs.filter({ !$0.isPinned }).isEmpty == true, let window = state?.associatedWindow as? BeamWindow {
            // tab was dragged out from a window with only 1 tab. bring back the originated window that was hidden.
            let frameOrigin = CGPoint(x: max(0, screenPoint.x - (window.frame.width / 2)),
                                      y: max(0, screenPoint.y - window.frame.height + (Toolbar.height / 2)))
            window.setFrameOrigin(frameOrigin)
            finishDropping(in: window.state, insertIndex: 0)
            window.state.mode = .web
            window.makeKeyAndOrderFront(nil)
        } else if let newWindow = AppDelegate.main.createWindow(withTabs: [], at: screenPoint) {
            finishDropping(in: newWindow.state, insertIndex: 0)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
