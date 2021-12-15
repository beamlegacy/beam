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
    private var designV2: Bool
    private weak var dragModel: TabsDragModel?

    internal init(tabsCount: Int, pinnedTabsCount: Int, containerSize: CGSize,
                  currentTabIsPinned: Bool, dragModel: TabsDragModel, designV2: Bool = false) {
        self.tabsCount = tabsCount
        self.pinnedTabsCount = pinnedTabsCount
        self.containerSize = containerSize
        self.currentTabIsPinned = currentTabIsPinned
        self.dragModel = dragModel
        self.designV2 = designV2
    }

    private var defaultPinnedWidth: CGFloat {
        designV2 ? OmniboxV2TabView.pinnedWidth : BrowserTabView.pinnedWidth
    }

    private var minimumActiveWidth: CGFloat {
        designV2 ? OmniboxV2TabView.minimumActiveWidth : BrowserTabView.minimumActiveWidth
    }

    private var minimumWidth: CGFloat {
        designV2 ? OmniboxV2TabView.minimumWidth : BrowserTabView.minimumWidth
    }

    var separatorWidth: CGFloat {
        designV2 ? 4 : 0
    }

    var separatorBetweenPinnedAndOther: CGFloat {
        designV2 ? 18 : 0
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
