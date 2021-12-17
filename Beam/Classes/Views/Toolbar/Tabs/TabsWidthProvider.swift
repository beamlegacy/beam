//
//  TabsWidthProvider.swift
//  Beam
//
//  Created by Remi Santos on 09/12/2021.
//

import Foundation

class TabsWidthProvider {
    private var tabsCount: Int
    private var pinnedTabsCount: Int
    private var containerSize: CGSize
    private var currentTabIsPinned: Bool
    private weak var dragModel: TabsDragModel?

    internal init(tabsCount: Int, pinnedTabsCount: Int, containerSize: CGSize,
                  currentTabIsPinned: Bool, dragModel: TabsDragModel) {
        self.tabsCount = tabsCount
        self.pinnedTabsCount = pinnedTabsCount
        self.containerSize = containerSize
        self.currentTabIsPinned = currentTabIsPinned
        self.dragModel = dragModel
    }

    private var defaultPinnedWidth: CGFloat {
        TabView.pinnedWidth
    }

    private var minimumActiveWidth: CGFloat {
        TabView.minimumActiveWidth
    }

    private var minimumWidth: CGFloat {
        TabView.minimumWidth
    }

    var separatorWidth: CGFloat {
        4
    }

    var separatorBetweenPinnedAndOther: CGFloat {
        18
    }

    var hasEnoughSpaceForAllTabs: Bool {
        let defaultWidth = widthForTab(selected: false, pinned: false)
        return defaultWidth > minimumWidth
    }

    private func availableWidthForUnpinneds(pinnedTabsCount: Int) -> CGFloat {
        guard pinnedTabsCount > 0 else { return containerSize.width }
        return containerSize.width
        - separatorBetweenPinnedAndOther
        - (CGFloat(pinnedTabsCount) * defaultPinnedWidth)
        - (CGFloat(pinnedTabsCount - 1) * separatorWidth)
    }

    func widthForTab(selected: Bool, pinned: Bool) -> CGFloat {
        guard !pinned else { return defaultPinnedWidth }
        var pinnedTabsCount = pinnedTabsCount
        if dragModel?.draggingOverPins == true && !currentTabIsPinned {
            pinnedTabsCount += 1
        } else if dragModel?.draggingOverIndex != nil && dragModel?.draggingOverPins != true && currentTabIsPinned {
            pinnedTabsCount -= 1
        }
        let availableWidth = availableWidthForUnpinneds(pinnedTabsCount: pinnedTabsCount)
        let unpinnedTabsCount = tabsCount - pinnedTabsCount
        guard unpinnedTabsCount > 0 else { return availableWidth }
        let availableWidthWithoutSeparators = availableWidth - (CGFloat(unpinnedTabsCount) * separatorWidth)
        var tabWidth = availableWidthWithoutSeparators / CGFloat(unpinnedTabsCount)
        if tabWidth < minimumActiveWidth {
            // not enough space for all tabs
            tabWidth = (availableWidthWithoutSeparators - minimumActiveWidth) / CGFloat(unpinnedTabsCount - 1)
        }
        return max(selected ? minimumActiveWidth : minimumWidth, tabWidth)
    }
}
