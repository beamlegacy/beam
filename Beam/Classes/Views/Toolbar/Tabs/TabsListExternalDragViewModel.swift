//
//  TabsListExternalDragViewModel.swift
//  Beam
//
//  Created by Remi Santos on 30/04/2022.
//

import Foundation
import BeamCore

class TabsListExternalDragViewModel: ObservableObject {

    @Published var isDraggingTabOutside = false
    var dropStartLocation: CGPoint?
    var isDroppingAnExternalTab = false

    private weak var data: BeamData?
    private weak var state: BeamState?
    private weak var tabsManager: BrowserTabsManager?

    func setup(withState state: BeamState?, tabsMananger: BrowserTabsManager?) {
        self.data = state?.data
        self.state = state
        self.tabsManager = tabsMananger
    }

    /// Prepare the dragging source and item image, but doesn't start the dragging yet.
    func prepareExternalDraggingOfcurrentTab(atLocation location: CGPoint) {
        guard data?.currentDraggingSession == nil, let state = self.state, let tab = tabsManager?.currentTab else { return }
        let dragSource = TabExternalDraggingSource(state: state, delegate: self)
        let dragItem = dragSource.startDraggingItem(for: tab, location: location)
        data?.currentDraggingSession = .init(draggedObject: tab, draggingSource: dragSource, draggingItem: dragItem)
    }

    /// Triggers the actual dragging session with the previously prepared dragging source and item
    func startExternalDraggingOfCurrentTab(atLocation location: CGPoint) {
        guard !isDraggingTabOutside else { return }
        isDraggingTabOutside = true

        guard data?.currentDraggingSession?.draggingSession == nil, let event = NSApp.currentEvent,
              let currentTab = tabsManager?.currentTab, let view = state?.associatedWindow?.contentView else { return }

        tabsManager?.removeTab(tabId: currentTab.id, suggestedNextCurrentTab: nil)
        if tabsManager?.tabs.filter({ !$0.isPinned }).isEmpty == true {
            // hide the origin window, we will close it if tab is moved to another window, or unhide instead of creating a new one.
            state?.associatedWindow?.orderOut(self)
        }

        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .default)

        if let dragSource = data?.currentDraggingSession?.draggingSource as? TabExternalDraggingSource,
            let dragItem = data?.currentDraggingSession?.draggingItem {
            dragSource.updateInitialDragginItemLocation(dragItem, location: location)
        } else {
            prepareExternalDraggingOfcurrentTab(atLocation: location)
        }

        guard let dragSource = data?.currentDraggingSession?.draggingSource,
              let dragItem = data?.currentDraggingSession?.draggingItem else {
                  Logger.shared.logError("Couldn't start tab external dragging session", category: .ui)
                  return
              }

        DispatchQueue.main.async { // starting the drag async to let the internal drag gesture finish properly
            let dragSession = view.beginDraggingSession(with: [dragItem], event: event, source: dragSource)
            dragSession.animatesToStartingPositionsOnCancelOrFail = false
            self.data?.currentDraggingSession?.draggingSession = dragSession
        }
    }

    func dropOfExternalTabStarted(atLocation location: CGPoint) {
        data?.currentDraggingSession?.dropHandledByBeamUI = true
        dropStartLocation = location
        isDroppingAnExternalTab = true
        isDraggingTabOutside = false
    }

    func dropOfExternalTabExitedWindow(tab: BrowserTab) {
        data?.currentDraggingSession?.dropHandledByBeamUI = false
        tabsManager?.removeTab(tabId: tab.id, suggestedNextCurrentTab: nil)
    }
}

extension TabsListExternalDragViewModel: TabExternalDraggingSourceDelegate {
    func tabExternalDragSessionEnded() {
        isDraggingTabOutside = false
    }
}
