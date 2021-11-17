//
//  BrowserTabBarDragModel.swift
//  Beam
//
//  Created by Remi Santos on 18/10/2021.
//

import Foundation
import SwiftUI

class BrowserTabBarDragModel: ObservableObject {
    @Published var offset = CGPoint.zero
    @Published var draggingOverIndex: Int?
    @Published var dragStartIndex: Int?
    @Published var draggingOverPins: Bool = false {
        didSet {
            guard draggingOverPins != oldValue || defaultTabWidth == 0 else { return }
            defaultTabWidth = tabWidth(selected: false, pinned: false)
            activeTabWidth = tabWidth(selected: true, pinned: false)
            pinnedTabWidth = tabWidth(selected: false, pinned: true)
        }
    }

    private var dragStartScrollOffset: CGFloat = 0
    private var widthProvider: TabWidthProvider?
    private var defaultTabWidth: CGFloat = 0
    private var activeTabWidth: CGFloat = 0
    private var pinnedTabWidth: CGFloat = 0
    private var tabsCount: Int = 0
    private var pinnedTabsCount: Int = 0

    var widthForDraggingTab: CGFloat {
        draggingOverPins ? pinnedTabWidth : activeTabWidth
    }

    func prepareForDrag(gestureValue: DragGesture.Value, scrollContentOffset: CGFloat,
                        currentTabIndex: Int, tabsCount: Int, pinnedTabsCount: Int,
                        widthProvider: TabWidthProvider) {

        self.tabsCount = tabsCount
        self.pinnedTabsCount = pinnedTabsCount
        self.widthProvider = widthProvider
        self.pinnedTabWidth = tabWidth(selected: false, pinned: true)
        self.dragStartScrollOffset = scrollContentOffset

        var locationX = gestureValue.startLocation.x
        let pinnedTabsMaxX = CGFloat(pinnedTabsCount) * pinnedTabWidth
        self.draggingOverPins = locationX < pinnedTabsMaxX

        var tabIndex: Int // guess start index
        if draggingOverPins {
            tabIndex = Int((locationX / pinnedTabWidth).rounded(.down))
        } else {
            locationX += scrollContentOffset
            tabIndex = Int(((locationX - pinnedTabsMaxX) / defaultTabWidth).rounded(.down)) + pinnedTabsCount
            if tabIndex > currentTabIndex && currentTabIndex >= pinnedTabsCount {
                let unpinnedLocation = locationX - pinnedTabsMaxX
                if (unpinnedLocation) > defaultTabWidth * CGFloat(currentTabIndex - pinnedTabsCount) + activeTabWidth {
                    tabIndex = Int(((unpinnedLocation - (activeTabWidth - defaultTabWidth)) / defaultTabWidth).rounded(.down)) + pinnedTabsCount
                } else {
                    tabIndex = currentTabIndex
                }
            }
        }
        self.dragStartIndex = tabIndex.clamp(0, tabsCount - 1)
    }

    func cleanAfterDrag() {
        offset = .zero
        widthProvider = nil
        defaultTabWidth = 0
        activeTabWidth = 0
        pinnedTabWidth = 0
        draggingOverPins = false
        draggingOverIndex = nil
        dragStartIndex = nil
        dragStartScrollOffset = 0
        tabsCount = 0
        pinnedTabsCount = 0
    }

    private func tabWidth(selected: Bool, pinned: Bool) -> CGFloat {
        widthProvider?.widthForTab(selected: selected, pinned: pinned) ?? 0
    }

    private func pinnedTabsCountDuringDrag() -> CGFloat {
        guard let dragStartIndex = dragStartIndex else { return 0 }
        return CGFloat(pinnedTabsCount - (dragStartIndex < pinnedTabsCount ? 1 : 0))
    }

    private func pinnedTabMinXDuringDrag(pinnedTabIndex: Int) -> CGFloat {
        CGFloat(pinnedTabIndex) * pinnedTabWidth
    }

    private func unpinnedTabMinXDuringDrag(tabIndex: Int) -> CGFloat {
        let pinnedTabsCountDuringDrag = pinnedTabsCountDuringDrag()
        return (pinnedTabsCountDuringDrag * pinnedTabWidth) + (CGFloat(tabIndex) - pinnedTabsCountDuringDrag) * defaultTabWidth
    }

    private func calculateNewOffsetXOnDrag(fromGesture gestureValue: DragGesture.Value, scrollContentOffset: CGFloat) -> CGFloat {
        guard let dragStartIndex = dragStartIndex else { return 0 }
        let locationX = gestureValue.location.x
        let startLocationX = gestureValue.startLocation.x
        let pinnedTabsMaxX = pinnedTabWidth * CGFloat(pinnedTabsCount)
        let currentTabOrigin: CGFloat
        if dragStartIndex < pinnedTabsCount || draggingOverPins {
            currentTabOrigin = pinnedTabMinXDuringDrag(pinnedTabIndex: dragStartIndex)
        } else {
            currentTabOrigin = unpinnedTabMinXDuringDrag(tabIndex: dragStartIndex) - scrollContentOffset
        }
        var offsetX = currentTabOrigin + (locationX - startLocationX)

        let minOffsetXBeforePinning = pinnedTabsMaxX + pinnedTabWidth
        let minOverlap: CGFloat = 10
        if dragStartIndex >= pinnedTabsCount {
            self.draggingOverPins = locationX <= (pinnedTabsMaxX + pinnedTabWidth)
            if offsetX < (pinnedTabsMaxX - minOverlap) && locationX > minOffsetXBeforePinning {
                // resistance to convert a tab to a pinned tab.
                offsetX = pinnedTabsMaxX - minOverlap
            } else if locationX < minOffsetXBeforePinning {
                let locationInTab = startLocationX - currentTabOrigin
                if locationInTab > pinnedTabWidth {
                    offsetX += locationInTab - pinnedTabWidth/2
                }
            }
        } else if dragStartIndex < pinnedTabsCount {
            self.draggingOverPins = locationX <= pinnedTabsMaxX
            if locationX > pinnedTabsMaxX {
                offsetX -= pinnedTabWidth
            }
        }
        return offsetX
    }

    func dragGestureChanged(gestureValue: DragGesture.Value, scrollContentOffset: CGFloat, containerGeometry: GeometryProxy) {

        let scrollContentOffset = dragStartScrollOffset // somehow reorder tabs sends wrong content offset. we don't support scrolling happening while dragging for now.
        guard let dragStartIndex = dragStartIndex else { return }

        let offsetX = calculateNewOffsetXOnDrag(fromGesture: gestureValue, scrollContentOffset: scrollContentOffset)
        let offset = CGPoint(x: offsetX.clamp(0, containerGeometry.size.width - activeTabWidth), y: 0)

        var newDragIndex: Int?
        if let draggingOverIndex = self.draggingOverIndex {
            var thresholdMinX: CGFloat // Left
            var thresholdMaxX: CGFloat // Right
            if draggingOverPins {
                newDragIndex = Int((gestureValue.location.x / pinnedTabWidth).rounded(.down))
            } else {
                if draggingOverIndex < pinnedTabsCount {
                    thresholdMinX = pinnedTabMinXDuringDrag(pinnedTabIndex: draggingOverIndex)
                    thresholdMaxX = thresholdMinX + activeTabWidth
                } else {
                    thresholdMinX = unpinnedTabMinXDuringDrag(tabIndex: draggingOverIndex)
                    thresholdMaxX = thresholdMinX + activeTabWidth
                }
                let gestureX = gestureValue.location.x + scrollContentOffset
                if gestureX < thresholdMinX {
                    newDragIndex = draggingOverIndex - 1
                } else if gestureX > thresholdMaxX {
                    newDragIndex = draggingOverIndex + 1
                }
            }
        } else {
            newDragIndex = dragStartIndex
        }

        if let idx = newDragIndex {
            self.draggingOverIndex = idx.clamp(0, tabsCount - 1)
        }
        self.offset = offset
    }

    func dragGestureEnded(scrollContentOffset: CGFloat) {
        guard let draggingOverIndex = draggingOverIndex else { return }
        let x: CGFloat
        if draggingOverIndex < pinnedTabsCount {
            x = pinnedTabMinXDuringDrag(pinnedTabIndex: draggingOverIndex)
        } else {
            x = unpinnedTabMinXDuringDrag(tabIndex: draggingOverIndex) - scrollContentOffset
        }
        offset = CGPoint(x: x, y: 0)
    }
}
