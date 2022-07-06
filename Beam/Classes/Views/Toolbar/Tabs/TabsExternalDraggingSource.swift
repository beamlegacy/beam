//
//  TabDragSession.swift
//  Beam
//
//  Created by Remi Santos on 19/04/2022.
//

import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static let beamBrowserTab = UTType("co.beamapp.browsertab") ?? .data
}

extension NSPasteboard.PasteboardType {
    static let beamBrowserTab = NSPasteboard.PasteboardType(UTType.beamBrowserTab.description)
}

class BrowserTabPasteboardProvider: NSObject, NSPasteboardItemDataProvider {
    private var url: URL?
    private weak var browserTab: BrowserTab?

    init(with tab: BrowserTab) {
        self.url = tab.url
        self.browserTab = tab
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if type == .URL, let url = url {
            pasteboard?.setString(url.absoluteString, forType: .URL)
        } else if type == .beamBrowserTab, let tab = browserTab {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(tab) {
                pasteboard?.setData(data, forType: .beamBrowserTab)
            }
        }
    }

    func pasteboardFinishedWithDataProvider(_ pasteboard: NSPasteboard) { }
}

/// Simple Tab View used to render the dragging session image
private struct TabViewForSnapshot: View {
    var tab: BrowserTab
    var size: CGSize
    var body: some View {
        TabView(tab: tab,
                isHovering: false,
                isSelected: true,
                isPinned: false,
                isSingleTab: false,
                isDragging: true,
                disableHovering: true,
                applyDraggingStyle: false)
            .frame(width: size.width, height: size.height)
            .drawingGroupExceptBigSur()
    }
}
private extension View {
    /// Somehow drawingGroup doesn't work properly with the snapshot on BigSur - BE-4650
    @ViewBuilder
    func drawingGroupExceptBigSur() -> some View {
        if #available(macOS 12.0, *) {
            self.drawingGroup()
        } else {
            self
        }
    }
}

protocol TabExternalDraggingSourceDelegate: AnyObject {
    func tabExternalDragSessionEnded()
}

class TabExternalDraggingSource: NSObject {

    private weak var state: BeamState?
    private weak var delegate: TabExternalDraggingSourceDelegate?
    private var browserTab: BrowserTab?
    private var cancellables = Set<AnyCancellable>()

    private var isDropHandledByBeamUI = false
    private var draggingImage: NSImage?
    private var transparentDraggingImage: NSImage?

    init(state: BeamState, delegate: TabExternalDraggingSourceDelegate) {
        self.state = state
        self.delegate = delegate
        super.init()
        state.data.$currentDraggingSession.sink { [weak self] dataSession in
            guard let dataSession = dataSession, let draggingSession = dataSession.draggingSession else { return }
            self?.willBeHandledByBeamUI(dataSession.dropHandledByBeamUI, session: draggingSession)
        }.store(in: &cancellables)
    }

    private func draggingItemFrame(location: CGPoint, convertToWindow window: NSWindow?) -> CGRect {
        var point = location
        if let window = window {
            point = location.flippedPointToBottomLeftOrigin(in: window)
        }

        let size = CGSize(width: 220, height: TabView.height)
        return CGRect(x: point.x, y: point.y,
                      width: size.width, height: size.height)
    }

    func startDraggingItem(for tab: BrowserTab, location: CGPoint) -> NSDraggingItem {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(BrowserTabPasteboardProvider(with: tab), forTypes: [ .beamBrowserTab])

        let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let itemFrame = draggingItemFrame(location: location, convertToWindow: state?.associatedWindow)

        let view = TabViewForSnapshot(tab: tab, size: itemFrame.size)
        self.draggingImage = view.snapshot()
        // using transparent image to avoid automatic sizing animation when setting a nil image
        self.transparentDraggingImage = NSImage(size: itemFrame.size, flipped: false, drawingHandler: { _ in true })
        dragItem.setDraggingFrame(itemFrame, contents: self.draggingImage)

        self.browserTab = tab
        self.isDropHandledByBeamUI = false
        return dragItem
    }

    func endDraggingItem() {
        cancellables.removeAll()
    }

    func updateInitialDragginItemLocation(_ dragItem: NSDraggingItem, location: CGPoint) {
        let itemFrame = draggingItemFrame(location: location, convertToWindow: state?.associatedWindow)
        dragItem.setDraggingFrame(itemFrame, contents: self.draggingImage)
    }

    private func willBeHandledByBeamUI(_ handled: Bool, session: NSDraggingSession) {
        guard handled != self.isDropHandledByBeamUI else { return }
        isDropHandledByBeamUI = handled
        session.enumerateDraggingItems(options: .concurrent,
                                       for: state?.associatedWindow?.contentView,
                                       classes: [NSPasteboardItem.self]) { [weak self] item, _, _ in
            item.setDraggingFrame(draggingItemFrame(location: session.draggingLocation, convertToWindow: nil),
                                  contents: handled ? self?.transparentDraggingImage : self?.draggingImage)
        }
    }
}

extension TabExternalDraggingSource: NSDraggingSource {

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) { }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) { }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        self.endDraggingItem()
        state?.data.currentDraggingSession = nil
        delegate?.tabExternalDragSessionEnded()
        guard let tab = self.browserTab, !self.isDropHandledByBeamUI else {
            if state?.associatedWindow?.isVisible == false && state?.browserTabsManager.tabs.filter({ !$0.isPinned }).isEmpty == true {
                state?.associatedWindow?.close()
            }
            return
        }

        state?.browserTabsManager.removeTab(tabId: tab.id)

        if state?.browserTabsManager.tabs.filter({ !$0.isPinned }).isEmpty == true, let window = state?.associatedWindow as? BeamWindow {
            // tab was dragged out from a window with only 1 tab. bring back the originated window that was hidden.
            let frameOrigin = CGPoint(x: max(0, screenPoint.x - (window.frame.width / 2)),
                                      y: max(0, screenPoint.y - window.frame.height + (Toolbar.height / 2)))
            window.setFrameOrigin(frameOrigin)

            window.state.browserTabsManager.addNewTabAndNeighborhood(tab, setCurrent: true)
            window.state.mode = .web
            window.makeKeyAndOrderFront(nil)
        } else {
            AppDelegate.main.createWindow(withTabs: [tab], at: screenPoint)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
