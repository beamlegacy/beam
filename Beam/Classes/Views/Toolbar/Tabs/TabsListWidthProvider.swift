//
//  TabsListWidthProvider.swift
//  Beam
//
//  Created by Remi Santos on 09/12/2021.
//

import Foundation

/// Provides the width of the tabs list items
///
/// we have 3 width cases
/// - a pinned tab has a fixed width
/// - a group item has a calculated fixed width
/// - any other items have a dynamic width depending on the remaining available space
final class TabsListWidthProvider {
    private var itemsCount: Int
    private var pinnedItemsCount: Int
    private var items: TabsListItemsSections
    private var containerSize: CGSize
    private var currentItemIsPinned: Bool

    private var defaultWidth: CGFloat = 0
    private var activeWidth: CGFloat = 0
    private var pinnedWidth: CGFloat = 0
    private(set) var computedFixedWidths: [String: CGFloat] = [:]

    private weak var dragModel: TabsDragModel?

    internal init(items: TabsListItemsSections, containerSize: CGSize,
                  currentItemIsPinned: Bool, dragModel: TabsDragModel) {
        self.items = items
        self.itemsCount = items.allItems.count
        self.pinnedItemsCount = items.pinnedItems.count
        self.containerSize = containerSize
        self.currentItemIsPinned = currentItemIsPinned
        self.dragModel = dragModel

        self.computeWidths()
    }

    private var defaultPinnedWidth: CGFloat {
        TabView.pinnedWidth
    }

    private var pinnedWidthWithMedia: CGFloat {
        TabView.pinnedWidthWithMedia
    }

    private var minimumActiveWidth: CGFloat {
        TabView.minimumActiveWidth
    }

    private var minimumWidth: CGFloat {
        TabView.minimumWidth
    }

    private var maximumWidth: CGFloat {
        TabView.maximumWidth
    }

    private var minimumGroupItemWidth: CGFloat {
        22
    }

    var separatorWidth: CGFloat {
        4
    }

    var separatorBetweenPinnedAndOther: CGFloat {
        18
    }

    private let defaultFont = BeamFont.medium(size: 11).nsFont

    private func widthForText(_ text: String) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: defaultFont]
        return (text as NSString).size(withAttributes: fontAttributes).width
    }

    private func computeWidths() {
        var customWidths = [String: CGFloat]()
        items.allItems.forEach { item in
            if item.isAGroupCapsule, let group = item.group {
                var width: CGFloat = minimumGroupItemWidth
                let hPadding: CGFloat = 8
                let title = item.displayedText
                if group.title?.isEmpty != false && group.collapsed && item.count ?? 0 >= 1000 {
                    width = 12 + (hPadding*2) // showing infinite icon
                } else if !title.isEmpty {
                    width = max(width, widthForText(title) + (hPadding*2))
                }
                customWidths[item.id] = width
            }
        }
        self.computedFixedWidths = customWidths
    }

    var hasEnoughSpaceForAllTabs: Bool {
        let defaultWidth = width(forItem: nil, selected: false, pinned: false)
        return defaultWidth > minimumWidth
    }

    private func availableWidthForUnpinneds(pinnedItemsCount: Int) -> CGFloat {
        var fixedWidthUsed: CGFloat = 0
        computedFixedWidths.values.forEach { fixedWidthUsed += ($0 + separatorWidth) }
        fixedWidthUsed += widthForAllPinnedItems(pinnedItemsCount: pinnedItemsCount)
        return containerSize.width - fixedWidthUsed
    }

    func widthForAllPinnedItems(pinnedItemsCount: Int) -> CGFloat {
        guard pinnedItemsCount > 0 else { return 0 }
        let allPinnedsWidth: CGFloat = Array(0..<pinnedItemsCount).reduce(into: 0) { partialResult, index in
            partialResult += width(forItemAtIndex: index, selected: false, pinned: true) + separatorWidth
        }
        return separatorBetweenPinnedAndOther + allPinnedsWidth - separatorWidth
    }

    func width(forItemAtIndex index: Int, selected: Bool, pinned: Bool) -> CGFloat {
        guard index >= 0 && index < items.allItems.count else { return 0 }
        let item = items.allItems[index]
        return width(forItem: item, selected: selected, pinned: pinned)
    }

    func width(forItem item: TabsListItem?, selected: Bool, pinned: Bool) -> CGFloat {
        if let itemId = item?.id, let customWidth = computedFixedWidths[itemId] {
            return customWidth
        }
        guard !pinned else {
            if item?.tab?.mediaPlayerController?.isPlaying == true {
                return pinnedWidthWithMedia
            }
            return defaultPinnedWidth
        }
        var pinnedItemsCount = pinnedItemsCount
        if dragModel?.draggingOverPins == true && !currentItemIsPinned {
            pinnedItemsCount += 1
        } else if dragModel?.draggingOverIndex != nil && dragModel?.draggingOverPins != true && currentItemIsPinned {
            pinnedItemsCount -= 1
        }
        let dynamicItemsCount = itemsCount - computedFixedWidths.count - pinnedItemsCount
        let availableWidth = availableWidthForUnpinneds(pinnedItemsCount: pinnedItemsCount)
        guard dynamicItemsCount > 0 else { return availableWidth }
        let availableWidthWithoutSeparators = availableWidth - (CGFloat(dynamicItemsCount) * separatorWidth)
        var tabWidth = availableWidthWithoutSeparators / CGFloat(dynamicItemsCount)
        if tabWidth < minimumActiveWidth {
            // not enough space for all tabs
            let numberOfUnpinnedActiveItems = currentItemIsPinned ? 0 : 1
            let numberOfInactiveDynamicItems = CGFloat(dynamicItemsCount - numberOfUnpinnedActiveItems)
            let availableWidthForInactiveDynamicItems = availableWidthWithoutSeparators - minimumActiveWidth * CGFloat(numberOfUnpinnedActiveItems)
            tabWidth = availableWidthForInactiveDynamicItems / numberOfInactiveDynamicItems
        }
        tabWidth = max(selected ? minimumActiveWidth : minimumWidth, tabWidth)
        let hasSingleTab = itemsCount - pinnedItemsCount == 1
        if !hasSingleTab {
            tabWidth = min(tabWidth, maximumWidth)
        }
        return tabWidth
    }
}
