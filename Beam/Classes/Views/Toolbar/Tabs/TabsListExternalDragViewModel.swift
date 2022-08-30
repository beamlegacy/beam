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
    var isDroppingATabGroup = false

    private weak var data: BeamData?
    private weak var state: BeamState?
    private weak var tabsManager: BrowserTabsManager?

    func setup(withState state: BeamState?, tabsMananger: BrowserTabsManager?) {
        self.data = state?.data
        self.state = state
        self.tabsManager = tabsMananger
    }

    func clearExternalDragging() {
        data?.currentDraggingSession?.draggingSource.endDraggingItem()
        data?.currentDraggingSession = nil
    }
}

// MARK: - Tab Drag
extension TabsListExternalDragViewModel {

    /// Prepare the dragging source and item image, but doesn't start the dragging yet.
    func prepareExternalDraggingOfCurrentTab(atLocation location: CGPoint) {
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

        tabsManager?.removeTab(tabId: currentTab.id)
        if tabsManager?.tabs.filter({ !$0.isPinned }).isEmpty == true {
            // hide the origin window, we will close it if tab is moved to another window, or unhide instead of creating a new one.
            state?.associatedWindow?.orderOut(self)
        }

        if PreferencesManager.isHapticFeedbackOn {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.alignment, performanceTime: .default)
        }

        if let dragSource = data?.currentDraggingSession?.draggingSource as? TabExternalDraggingSource,
            let dragItem = data?.currentDraggingSession?.draggingItem {
            dragSource.updateInitialDragginItemLocation(dragItem, location: location)
        } else {
            prepareExternalDraggingOfCurrentTab(atLocation: location)
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
        tabsManager?.removeTab(tabId: tab.id)
    }
}

extension TabsListExternalDragViewModel: TabExternalDraggingSourceDelegate {
    func tabExternalDragSessionEnded() {
        isDroppingAnExternalTab = false
        isDraggingTabOutside = false
    }
}

// MARK: - Tab Group Drag
extension TabsListExternalDragViewModel {

    /// Triggers a dragging session for the specified tab group
    func startExternalDraggingOfTabGroup(_ group: TabGroup, tabs: [BrowserTab], atLocation location: CGPoint, itemSize: CGSize, title: String) {
        guard !isDroppingATabGroup, data?.currentDraggingSession == nil, let state = self.state else { return }
        guard let event = NSApp.currentEvent, let view = state.associatedWindow?.contentView else { return }

        let dragSource = TabGroupExternalDraggingSource(state: state, delegate: self)
        let dragItem = dragSource.startDraggingItem(for: group, tabs: tabs, location: location, size: itemSize, title: title)
        data?.currentDraggingSession = .init(draggedObject: group, draggingSource: dragSource, draggingItem: dragItem)

        removeTabGroupFromWindow(group)

        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .default)

        if let dragSource = data?.currentDraggingSession?.draggingSource as? TabGroupExternalDraggingSource,
           let dragItem = data?.currentDraggingSession?.draggingItem {
            dragSource.updateInitialDragginItemLocation(dragItem, location: location)
        } else {
            prepareExternalDraggingOfCurrentTab(atLocation: location)
        }

        guard let dragSource = data?.currentDraggingSession?.draggingSource,
              let dragItem = data?.currentDraggingSession?.draggingItem else {
            Logger.shared.logError("Couldn't start tab group external dragging session", category: .ui)
            return
        }

        DispatchQueue.main.async { // starting the drag async to let the internal drag gesture finish properly
            let dragSession = view.beginDraggingSession(with: [dragItem], event: event, source: dragSource)
            dragSession.animatesToStartingPositionsOnCancelOrFail = false
            self.data?.currentDraggingSession?.draggingSession = dragSession
        }
    }

    private func removeTabGroupFromWindow(_ group: TabGroup) {
        // remove the entire group
        let tabs = tabsManager?.tabs.filter {
            guard let pageId = $0.pageId else { return false }
            return group.pageIds.contains(pageId)            
        }
        tabs?.forEach { tabsManager?.removeTab(tabId: $0.id) }
        if tabsManager?.tabs.filter({ !$0.isPinned }).isEmpty == true {
            // hide the origin window, we will close it if tab is moved to another window, or unhide instead of creating a new one.
            state?.associatedWindow?.orderOut(self)
        }
    }

    func dropOfExternalTabGroupStarted(atLocation location: CGPoint) {
        data?.currentDraggingSession?.dropHandledByBeamUI = true
        dropStartLocation = location
        isDroppingATabGroup = true
    }

    func dropOfExternalTabGroupExitedWindow(group: TabGroup) {
        data?.currentDraggingSession?.dropHandledByBeamUI = false
        removeTabGroupFromWindow(group)
    }
}

extension TabsListExternalDragViewModel: TabGroupExternalDraggingSourceDelegate {
    func tabGroupExternalDragSessionEnded() {
        isDroppingATabGroup = false
    }
}
