//
//  TabsDragModel.swift
//  Beam
//
//  Created by Remi Santos on 18/10/2021.
//

import Foundation
import SwiftUI

/// Replacement of SwiftUI GestureValue to be used manually.
struct TabGestureValue {
    var startLocation: CGPoint
    var location: CGPoint
    var time: Date
}

class TabsDragModel: ObservableObject {
    @Published var offset = CGPoint.zero
    @Published var draggingOverIndex: Int?
    @Published var dragStartIndex: Int?
    @Published var draggingOverGroup: TabGroup?
    @Published var draggingOverPins: Bool = false {
        didSet {
            guard (draggingOverPins != oldValue || activeItemWidth == 0), let widthProvider = widthProvider else { return }
            activeItemWidth = widthProvider.width(forItem: nil, selected: true, pinned: false) + spaceBetweenItems
            pinnedItemWidth = widthProvider.width(forItem: nil, selected: false, pinned: true) + spaceBetweenItems
        }
    }

    private var dragStartScrollOffset: CGFloat = 0
    private var dragStartItemOrigin: CGFloat = 0
    private var widthProvider: TabsListWidthProvider?
    private var activeItemWidth: CGFloat = 0
    private var pinnedItemWidth: CGFloat = 0
    private var spaceBetweenItems: CGFloat = 0
    private var spaceBetweenSections: CGFloat = 0
    private var allItems: [TabsListItem] = []
    private var itemsCount: Int = 0
    private var activeItemIndexAtStart: Int?
    private var initialPinnedItemsCount: Int = 0
    private var singleTabCenteringAdjustment: CGFloat = 0
    private var unlistedDraggedItemWidth: CGFloat?

    var isDragging: Bool {
        draggingOverIndex != nil
    }
    var isDraggingUnlistedItem: Bool {
        isDragging && isHandlingUnlistedItem
    }
    private var isHandlingUnlistedItem: Bool {
        unlistedDraggedItemWidth != nil
    }
    var unpinnedItemsCount: Int {
        itemsCount - initialPinnedItemsCount
    }
    var widthForDraggedItem: CGFloat {
        isDraggingUnlistedItem ? (unlistedDraggedItemWidth ?? 0) : (draggingOverPins ? pinnedItemWidth : activeItemWidth) - spaceBetweenItems
    }
    var widthForDraggingSpacer: CGFloat {
        widthForDraggedItem
    }
    var dragStartedFromPinnedItem: Bool {
        guard let dragStartIndex = dragStartIndex else { return false }
        return dragStartIndex < initialPinnedItemsCount
    }

    private var draggedItemCanBePinned: Bool {
        !isHandlingUnlistedItem
    }

    private var draggedItemCanBeGrouped: Bool {
        !isHandlingUnlistedItem
    }

    private var pinnedItemsCountDuringDrag: Int {
        var count = initialPinnedItemsCount
        if !draggedItemCanBePinned {
            // can't have been changed
        } else if dragStartedFromPinnedItem && !draggingOverPins {
            count -= 1
        } else if !dragStartedFromPinnedItem && draggingOverPins {
            count += 1
        }
        return count
    }

    private var pinnedSectionMaxX: CGFloat {
        guard initialPinnedItemsCount > 0 else { return 0 }
        return (CGFloat(initialPinnedItemsCount) * pinnedItemWidth) + spaceBetweenSections
    }

    private func itemIndex(atLocation: CGFloat, activeItemIndex: Int) -> Int {
        let pinnedSectionMaxX = pinnedSectionMaxX
        guard atLocation > pinnedSectionMaxX else {
            return Int((atLocation / pinnedItemWidth).rounded(.down))
        }
        guard let widthProvider = widthProvider else {
            assertionFailure("Tabs Drag model should have a width provider")
            return 0
        }

        let locationInUnpinnedItems = atLocation - pinnedSectionMaxX

        var index = initialPinnedItemsCount - 1
        var itemMaxX: CGFloat = 0
        while itemMaxX < locationInUnpinnedItems {
            index += 1
            itemMaxX += widthProvider.width(forItemAtIndex: index, selected: index == activeItemIndex, pinned: false) + spaceBetweenItems
        }
        return index
    }

    func prepareForDrag(gestureValue: TabGestureValue, scrollContentOffset: CGFloat,
                        currentItemIndex: Int?, sections: TabsListItemsSections, singleTabCenteringAdjustment: CGFloat = 0,
                        widthProvider: TabsListWidthProvider) {
        self.allItems = sections.allItems
        self.itemsCount = sections.allItems.count
        self.activeItemIndexAtStart = currentItemIndex
        self.initialPinnedItemsCount = sections.pinnedItems.count
        self.widthProvider = widthProvider
        self.pinnedItemWidth = widthProvider.width(forItem: nil, selected: false, pinned: true)
        self.spaceBetweenItems = widthProvider.separatorWidth
        self.spaceBetweenSections = widthProvider.separatorBetweenPinnedAndOther - self.spaceBetweenItems
        self.dragStartScrollOffset = scrollContentOffset
        self.singleTabCenteringAdjustment = singleTabCenteringAdjustment

        var locationX = gestureValue.startLocation.x
        let pinnedItemsMaxX = pinnedSectionMaxX
        self.draggingOverPins = locationX < pinnedItemsMaxX

        if !draggingOverPins {
            locationX += scrollContentOffset
        }
        var targetIndex = itemIndex(atLocation: locationX, activeItemIndex: currentItemIndex ?? 0) // guessed start index
        targetIndex = clampedIndex(targetIndex) ?? targetIndex
        dragStartItemOrigin = itemMinX(atIndex: targetIndex)
        self.dragStartIndex = targetIndex
    }

    func prepareForDraggingUnlistedItem(ofWidth width: CGFloat) {
        unlistedDraggedItemWidth = width
    }

    func frameForItemAtIndex(_ index: Int) -> CGRect {
        let width = widthProvider?.width(forItemAtIndex: index, selected: false, pinned: index < initialPinnedItemsCount) ?? 0
        let x = itemMinX(atIndex: index)
        return CGRect(x: x, y: 0, width: width + spaceBetweenItems, height: 0)
    }

    func cleanAfterDrag() {
        offset = .zero
        widthProvider = nil
        activeItemWidth = 0
        pinnedItemWidth = 0
        unlistedDraggedItemWidth = nil
        draggingOverPins = false
        draggingOverIndex = nil
        dragStartIndex = nil
        dragStartScrollOffset = 0
        allItems = []
        itemsCount = 0
        activeItemIndexAtStart = nil
        initialPinnedItemsCount = 0
    }

    private func itemMinX(atIndex: Int, ignoringItemAtIndex: Int? = nil) -> CGFloat {
        guard let widthProvider = widthProvider else { return 0 }
        let pinnedItemsCount = pinnedItemsCountDuringDrag
        guard atIndex >= pinnedItemsCount else {
            return pinnedItemWidth * CGFloat(atIndex)
        }
        var minX: CGFloat = pinnedSectionMaxX
        var endIndex = atIndex
        if let ignoringItemAtIndex = ignoringItemAtIndex, ignoringItemAtIndex < atIndex {
            if ignoringItemAtIndex < pinnedItemsCount {
                minX -= widthProvider.width(forItemAtIndex: ignoringItemAtIndex, selected: false, pinned: true) + spaceBetweenItems
            } else {
                endIndex += 1
            }
        }
        for i in pinnedItemsCount..<endIndex {
            guard i != ignoringItemAtIndex else { continue }
            minX += widthProvider.width(forItemAtIndex: i, selected: false, pinned: false) + spaceBetweenItems
        }
        if unpinnedItemsCount == 1 {
            minX -= singleTabCenteringAdjustment / 2
        }
        return minX
    }

    /// Determines the offset to apply to the dragged tab
    private func calculateNewOffsetXOnDrag(fromGesture gestureValue: TabGestureValue, scrollContentOffset: CGFloat) -> (x: CGFloat, isNowOverPins: Bool) {
        let locationX = gestureValue.location.x
        let startLocationX = gestureValue.startLocation.x
        let pinnedItemsMaxX = pinnedSectionMaxX
        var currentItemOrigin: CGFloat = dragStartItemOrigin
        if !dragStartedFromPinnedItem && !draggingOverPins {
            currentItemOrigin -= scrollContentOffset
        }
        var offsetX = currentItemOrigin + (locationX - startLocationX)

        let minOffsetXBeforePinning = pinnedItemsMaxX + pinnedItemWidth - spaceBetweenSections
        let minOverlap: CGFloat = 10
        var isNowOverPins = draggingOverPins
        if draggedItemCanBePinned {
            if !dragStartedFromPinnedItem {
                isNowOverPins = locationX <= minOffsetXBeforePinning
                if unpinnedItemsCount > 1 && offsetX < (pinnedItemsMaxX - minOverlap) && locationX > minOffsetXBeforePinning {
                    // resistance to convert a tab to a pinned tab.
                    offsetX = pinnedItemsMaxX - minOverlap
                } else if locationX < minOffsetXBeforePinning {
                    let locationInItem = startLocationX - currentItemOrigin
                    if locationInItem > pinnedItemWidth {
                        offsetX += locationInItem - pinnedItemWidth/2
                    }
                }
            } else if dragStartedFromPinnedItem {
                isNowOverPins = locationX <= pinnedItemsMaxX
                if !isNowOverPins {
                    offsetX -= pinnedItemWidth
                }
            }
        } else {
            isNowOverPins = false
            offsetX = max(offsetX, minOffsetXBeforePinning)
        }
        return (offsetX, isNowOverPins)
    }

    /// Determines the targeted Tab Group depending on the location
    /// Allowing things like moving a tab out of a group by reaching the trailing half of the last tab of the group.
    private func calculateDraggingOverGroup(_ draggingOverIndex: Int, dragStartIndex: Int, offsetX: CGFloat) -> TabGroup? {
        guard draggedItemCanBeGrouped else { return nil }
        let itemFrame = frameForItemAtIndex(draggingOverIndex)
        let items = allItems
        guard draggingOverIndex < items.count else { return nil }
        let item = items[draggingOverIndex]
        let previousItem = draggingOverIndex > 0 ? items[draggingOverIndex - 1] : nil
        let group = item.group
        guard group != nil || previousItem?.group != nil else { return nil }

        guard itemFrame.width > 0 && offsetX < itemFrame.maxX else {
            if item.isAGroupCapsule && offsetX > itemFrame.maxX && draggingOverIndex >= dragStartIndex {
                return group
            }
            return nil
        }

        let percentIn = (offsetX - itemFrame.minX) / itemFrame.width
        if item.isAGroupCapsule && draggingOverIndex < dragStartIndex {
            return nil
        } else if percentIn > 0.5 && draggingOverIndex >= dragStartIndex {
            let nextItem = draggingOverIndex < items.count - 1 ? items[draggingOverIndex + 1] : nil
            if (nextItem == nil || nextItem?.group != group)
                && (draggingOverIndex > dragStartIndex || (previousItem?.group == group && previousItem?.isAGroupCapsule != true)) {
                return nil
            }
        } else if percentIn < 0.5 && draggingOverIndex <= dragStartIndex {
            if draggingOverIndex < dragStartIndex || group == nil {
                return previousItem?.group
            }
        }
        return group
    }

    private func clampedIndex(_ index: Int?) -> Int? {
        index?.clamp(draggedItemCanBePinned ? 0 : pinnedItemsCountDuringDrag,
                     itemsCount - (isDraggingUnlistedItem ? 0 : 1))
    }

    /// Determines over which item index the dragging is being performed
    /// - Returns: `nil` if we're still dragging over the same index.
    private func calculateNewDraggingOverIndex(fromGesture gestureValue: TabGestureValue,
                                               draggingOverIndex: Int, dragStartIndex: Int,
                                               isOverPins: Bool, scrollContentOffset: CGFloat) -> Int? {
        var newDragIndex: Int?
        if isOverPins {
            let locX = gestureValue.location.x
            if dragStartIndex < initialPinnedItemsCount && locX > pinnedItemWidth * CGFloat(initialPinnedItemsCount) {
                newDragIndex = initialPinnedItemsCount - 1
            } else {
                newDragIndex = Int((locX / pinnedItemWidth).rounded(.down))
            }
        } else {
            let hoveredItemIndex = min(draggingOverIndex, itemsCount - 1)
            var thresholdMinX = itemMinX(atIndex: hoveredItemIndex) // Left
            var thresholdMaxX = thresholdMinX // Right
            if isDraggingUnlistedItem, let widthProvider = widthProvider {
                let hoveredItemWidth = widthProvider.width(forItemAtIndex: hoveredItemIndex, selected: hoveredItemIndex == activeItemIndexAtStart, pinned: false)
                if unpinnedItemsCount == 1 {
                    if draggingOverIndex == itemsCount {
                        thresholdMaxX += hoveredItemWidth
                        thresholdMinX += (hoveredItemWidth / 2)
                    } else {
                        thresholdMaxX += (hoveredItemWidth / 2)
                    }
                } else {
                    thresholdMaxX += hoveredItemWidth
                }
            } else {
                thresholdMaxX += widthForDraggedItem
            }

            let gestureX = gestureValue.location.x + scrollContentOffset
            if gestureX < thresholdMinX {
                newDragIndex = draggingOverIndex - 1
            } else if gestureX > thresholdMaxX {
                newDragIndex = draggingOverIndex + 1
            }
            newDragIndex = clampedIndex(newDragIndex)
        }
        return newDragIndex
    }

    func dragGestureChanged(gestureValue: TabGestureValue, scrollContentOffset: CGFloat, containerGeometry: GeometryProxy) {

        let scrollContentOffset = dragStartScrollOffset // somehow reorder tabs sends wrong content offset. we don't support scrolling happening while dragging for now.
        guard let dragStartIndex = dragStartIndex else { return }

        let (offsetX, isNowOverPins) = calculateNewOffsetXOnDrag(fromGesture: gestureValue, scrollContentOffset: scrollContentOffset)
        if isNowOverPins != self.draggingOverPins {
            withAnimation(BeamAnimation.easeInOut(duration: 0.2)) {
                self.draggingOverPins = isNowOverPins
            }
        }
        let minX: CGFloat = unpinnedItemsCount == 1 && !draggingOverPins ? -60 : 0
        let offset = CGPoint(x: offsetX.clamp(minX, containerGeometry.size.width - widthForDraggedItem), y: gestureValue.location.y)

        var newDragIndex: Int?
        let shouldAnimateIndexMove = self.draggingOverIndex != nil
        if let draggingOverIndex = self.draggingOverIndex {
            newDragIndex = calculateNewDraggingOverIndex(fromGesture: gestureValue,
                                                         draggingOverIndex: draggingOverIndex,
                                                         dragStartIndex: dragStartIndex,
                                                         isOverPins: isNowOverPins,
                                                         scrollContentOffset: scrollContentOffset)
            if isNowOverPins {
                self.draggingOverGroup = nil
            } else if let idx = newDragIndex ?? self.draggingOverIndex {
                let gestureX = gestureValue.location.x + scrollContentOffset
                self.draggingOverGroup = calculateDraggingOverGroup(idx, dragStartIndex: dragStartIndex, offsetX: gestureX)
            }
        } else {
            newDragIndex = dragStartIndex
        }

        if let idx = clampedIndex(newDragIndex) {
            if shouldAnimateIndexMove {
                withAnimation(BeamAnimation.easeInOut(duration: 0.2)) {
                    self.draggingOverIndex = idx
                }
            } else {
                self.draggingOverIndex = idx
            }
        }
        self.offset = offset
    }

    func dragGestureEnded(scrollContentOffset: CGFloat) {
        guard let draggingOverIndex = draggingOverIndex else { return }
        var x = itemMinX(atIndex: draggingOverIndex, ignoringItemAtIndex: dragStartIndex)
        if !draggingOverPins {
            x -= scrollContentOffset
        }
        offset = CGPoint(x: x, y: 0)
    }
}
