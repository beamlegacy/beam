//
//  TabsListView.swift
//  Beam
//
//  Created by Remi Santos on 02/12/2021.
//

import SwiftUI
import BeamCore
import UniformTypeIdentifiers

private class TabsListViewModel: ObservableObject {
    var currentDragDidChangeCurrentTab = false
    var firstDragGestureValue: TabGestureValue?
    var lastTouchWasOnUnselectedTab: Bool = false
    var singleTabCenteringAdjustment: CGFloat = 0
    var singleTabCurrentFrame: CGRect?
    var lastItemCurrentFrame: CGRect?
    weak var mouseMoveMonitor: AnyObject?
    weak var otherMouseDownMonitor: AnyObject?
}

struct TabsListItem: Identifiable, CustomStringConvertible {
    var id: String {
        tab?.id.uuidString ?? group?.id.uuidString ?? "unknownItem"
    }
    var tab: BrowserTab?
    var group: TabGroup?
    var count: Int?

    var displayedText: String {
        if isAGroupCapsule, let group = group {
            var title = group.title ?? ""
            if group.collapsed, let count = count, count > 0 {
                if title.isEmpty {
                    title = "\(count)"
                } else {
                    title += " (\(count))"
                }
            }
            return title
        }
        return tab?.title ?? ""
    }

    var description: String {
        if let tab = tab {
            return "TabsListItem(tab: \(tab.title))"
        } else if let group = group {
            return "TabsListItem(group: \(group.title ?? group.id.uuidString))"
        }
        return "TabsListItem(unknown)"
    }

    var isATab: Bool {
        tab != nil
    }
    var isAGroupCapsule: Bool {
        group != nil && !isATab
    }
}

struct TabsListItemsSections {
    var allItems: [TabsListItem] = []

    var pinnedItems: [TabsListItem] = []
    var unpinnedItems: [TabsListItem] = []
}

struct TabsListView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @Environment(\.isMainWindow) private var isMainWindow

    var globalContainerGeometry: GeometryProxy?

    @State private var disableAnimation: Bool = false
    @State private var isAnimatingDrop: Bool = false

    @State private var hoveredIndex: Int?
    @State private var isChangingTabsCountWhileHovering: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentSize: CGFloat = 0
    @State private var draggableTabsAreas: [CGRect] = [] {
        didSet {
            windowInfo.undraggableWindowRects = draggableTabsAreas
        }
    }

    @StateObject private var dragModel = TabsDragModel()
    @StateObject private var externalDragModel = TabsListExternalDragViewModel()
    @StateObject private var viewModel = TabsListViewModel()
    @State private var contextMenuManager: TabsListContextMenuBuilder?

    private var sections: TabsListItemsSections {
        browserTabsManager.listItems
    }

    private var currentTab: BrowserTab? {
        browserTabsManager.currentTab
    }

    private var isDraggingATab: Bool {
        dragModel.draggingOverIndex != nil
    }

    private var selectedIndex: Int {
        guard let currentTab = currentTab else { return 0 }
        return sections.allItems.firstIndex(where: { $0.tab == currentTab }) ?? 0
    }

    private func pinnedTabs() -> [BrowserTab] {
        sections.pinnedItems.compactMap { item in
            item.tab
        }
    }

    private func widthProvider(for containerGeometry: GeometryProxy, sections: TabsListItemsSections) -> TabsListWidthProvider {
        TabsListWidthProvider(items: sections, containerSize: containerGeometry.size, currentItemIsPinned: currentTab?.isPinned == true, dragModel: dragModel)
    }

    private func calculateSingleTabAdjustment(_ scrollContainerProxy: GeometryProxy) -> CGFloat {
        guard let globalContainerGeometry = globalContainerGeometry else { return 0 }
        let containerGlobal: NSRect = globalContainerGeometry.frame(in: .global)
        let contentGlobal = scrollContainerProxy.frame(in: .global)
        let rightSpacing = containerGlobal.maxX - contentGlobal.maxX
        let leftSpacing = contentGlobal.minX - containerGlobal.minX
        let offsetX = leftSpacing - rightSpacing + containerGlobal.minX
        if contentGlobal.width - offsetX < TabView.minSingleTabWidth {
            // we have too much pinned tab to be able to center the single tab, so it will be aligned on the right.
            return 0
        }
        return offsetX
    }

    private func shouldShowSectionSeparator(tabsSections: TabsListItemsSections) -> Bool {
        let hasSingleOtherTab = tabsSections.unpinnedItems.count == 1
        if let dragOverIndex = dragModel.draggingOverIndex {
            return !(dragModel.draggingOverPins == true && !dragModel.dragStartedFromPinnedItem && dragOverIndex == tabsSections.pinnedItems.count)
        }
        return hasSingleOtherTab || (selectedIndex != tabsSections.pinnedItems.count && hoveredIndex != tabsSections.pinnedItems.count)
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func isSingleTab(atIndex: Int, in tabsSections: TabsListItemsSections) -> Bool {
        tabsSections.unpinnedItems.count == 1 && atIndex == tabsSections.pinnedItems.count
    }

    // MARK: - Rendering
    private var emptyDragSpacer: some View {
        Rectangle().fill(.clear)
            .frame(width: dragModel.widthForDraggingSpacer)
    }

    private var separator: some View {
        Separator(rounded: true, color: BeamColor.ToolBar.horizontalSeparator)
            .frame(height: 16)
            .padding(.horizontal, 1.5)
            .blendModeLightMultiplyDarkScreen()
    }

    private var scrollMask: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: scrollOffset > 0 ? 29 : 0)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .black.opacity(0.0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: scrollContentSize - scrollOffset - geometry.size.width > 0 ? 29 : 0)
            }
            .animation(BeamAnimation.easeInOut(duration: 0.3), value: scrollOffset)
        }
    }

    private let tabTransition = AnyTransition.asymmetric(insertion: .animatableOffset(offset: CGSize(width: 0, height: 40)).animation(BeamAnimation.spring(stiffness: 400, damping: 28))
                                                            .combined(with: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.05).delay(0.1))),
                                                         removal: .animatableOffset(offset: CGSize(width: 0, height: 40)).animation(BeamAnimation.spring(stiffness: 400, damping: 28))
                                                            .combined(with: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.05))))

    private func renderItem(_ item: TabsListItem, index: Int, selectedIndex: Int, isSingle: Bool,
                            canScroll: Bool, widthProvider: TabsListWidthProvider, centeringAdjustment: CGFloat = 0) -> some View {
        var selected = false
        var id = item.id
        let isPinned = item.tab?.isPinned == true
        if let tab = item.tab {
            selected = isSelected(tab)
            id = tabViewId(for: tab)
        }

        let group: TabGroup? = item.group
        let allItems = sections.allItems
        let nextItem: TabsListItem? = index < allItems.count - 1 ? allItems[index + 1] : nil
        var nextGroup: TabGroup? = nextItem?.group
        if dragModel.draggingOverIndex == index + 1 {
            if nextGroup == nil && dragModel.draggingOverGroup == group {
                nextGroup = dragModel.draggingOverGroup
            } else if nextGroup != nil && dragModel.draggingOverGroup == nil {
                nextGroup = dragModel.draggingOverGroup
            }
        }
        let previousItem: TabsListItem? = index > 0 ? allItems[index - 1] : nil
        let previousGroup: TabGroup? = previousItem?.group
        let isTabItem = item.tab != nil
        let nextItemIsTab = nextItem?.tab != nil

        let isTheDraggedTab = selected && isDraggingATab
        let isTheLastItem = nextItem == nil
        let dragStartIndex = dragModel.dragStartIndex ?? 0
        let showLeadingDragSpacer = index == dragModel.draggingOverIndex && index <= dragStartIndex
        let showTrailingDragSpacer = index == dragModel.draggingOverIndex && index > dragStartIndex

        let hideSeparator = isPinned
        || (canScroll && isTheLastItem)
        || (!isTheLastItem && ((!isTabItem && nextItemIsTab) || (isTabItem && !nextItemIsTab) || group != nextGroup))
        || (!isDraggingATab && (selectedIndex == index + 1 || selectedIndex == index || hoveredIndex == index + 1 || hoveredIndex == index))

        let width = max(0, widthProvider.width(forItem: item, selected: selected, pinned: isPinned) - centeringAdjustment)
        let areTabsFillingSpace = width < TabView.maximumWidth
        return HStack(spacing: 0) {
            if showLeadingDragSpacer {
                emptyDragSpacer
                separator.opacity(hideSeparator ? 0 : 1)
            }
            Group {
                if let tab = item.tab {
                    TabView(tab: tab, isSelected: selected, isPinned: tab.isPinned, isSingleTab: isSingle, isDragging: isTheDraggedTab,
                            disableAnimations: isAnimatingDrop, disableHovering: isChangingTabsCountWhileHovering,
                            isInMainWindow: isMainWindow,
                            onTouchDown: { onTabTouched(at: index) },
                            onTap: { onTabTapped(at: index, isRightMouse: $0, event: $1) },
                            onClose: { onItemClose(at: index) }, onCopy: { onItemCopy(at: index) },
                            onToggleMute: { onTabToggleMute(at: index) },
                            onFileDrop: { onFileDrop(at: index, url: $0) })
                } else if let group = item.group, let color = group.color {
                    TabClusteringGroupCapsuleView(title: group.title ?? "", color: color,
                                                  collapsed: group.collapsed, itemsCount: item.count ?? group.pageIds.count,
                                                  onTap: { (isRightMouse, event) in
                        if isRightMouse {
                            contextMenuManager?.showContextMenu(forGroup: group, with: event)
                        } else {
                            browserTabsManager.toggleGroupCollapse(group)
                        }
                    })
                }
            }
            .frame(width: isTheDraggedTab ? 0 : width)
            .opacity(isTheDraggedTab ? 0 : 1)
            .onHover { if $0 { hoveredIndex = index } }
            .background(!selected ? nil : GeometryReader { prxy in
                Color.clear.preference(key: CurrentTabGlobalFrameKey.self, value: .init(index: index, frame: prxy.safeTopLeftGlobalFrame(in: nil).rounded()))
            })
            .background(!isTheLastItem || areTabsFillingSpace ? nil : GeometryReader { prxy in
                Color.clear.preference(key: LastTabGlobalFrameKey.self, value: prxy.safeTopLeftGlobalFrame(in: nil).rounded())
            })
            if !isSingle && !isTheDraggedTab {
                separator.opacity(hideSeparator ? 0 : 1)
            }
            if showTrailingDragSpacer {
                emptyDragSpacer
                separator.opacity(hideSeparator ? 0 : 1)
            }
        }
        .frame(height: TabView.height)
        .overlay(
            group == nil || (isTheDraggedTab && dragModel.draggingOverGroup == nil) ? nil :
                TabViewGroupUnderline(color: group?.color ?? .init(),
                                 isBeginning: previousGroup != group, isEnd: nextGroup != group)
                .padding(.trailing, nextGroup != group ? widthProvider.separatorWidth : 0)
                .padding(.trailing, (!isTheDraggedTab || nextGroup != group) && showTrailingDragSpacer && dragModel.draggingOverGroup == nil ? dragModel.widthForDraggingSpacer : 0)
                .padding(.leading, (!isTheDraggedTab || nextGroup != group) && showLeadingDragSpacer && dragModel.draggingOverGroup == nil ? dragModel.widthForDraggingSpacer : 0)
            ,
            alignment: .bottom)
        .overlay(
            // We're dragging right the previousItem's group. Showing a target group underline.
            group == nil && dragModel.draggingOverGroup != nil && dragModel.draggingOverIndex == index ?
                TabViewGroupUnderline(color: dragModel.draggingOverGroup?.color ?? .init(),
                                      isBeginning: false, isEnd: true)
                .padding(.trailing, showLeadingDragSpacer && !isTheDraggedTab ? dragModel.widthForDraggingSpacer : widthProvider.separatorWidth)
            : nil,
            alignment: .bottom)
        .contentShape(Rectangle())
        .disabled(isDraggingATab && !isTheDraggedTab)
        .id(id)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibility(identifier: accessibilityIdentifier(for: item))
        .transition(isAnimatingDrop ? .identity : tabTransition)
    }

    @ViewBuilder
    private var draggedItem: some View {
        if let currentTab = currentTab, isDraggingATab {
            TabView(tab: currentTab, isSelected: true,
                    isPinned: dragModel.draggingOverPins,
                    isSingleTab: !dragModel.draggingOverPins && sections.unpinnedItems.count <= 1,
                    isDragging: true, disableHovering: externalDragModel.isDroppingAnExternalTab)
            .frame(width: dragModel.widthForDraggedItem)
            .transition(.asymmetric(
                insertion: .identity,
                removal: .opacity.combined(with: .scale(scale: 0.98)).animation(BeamAnimation.easeInOut(duration: 0.08))
            ))
            .offset(x: dragModel.offset.x, y: 0)
            .opacity(externalDragModel.isDraggingTabOutside ? 0 : 1)
            .zIndex(10)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let widthProvider = widthProvider(for: geometry, sections: sections)
            let selectedIndex = selectedIndex
            let hasSingleOtherTab = sections.unpinnedItems.count == 1 && sections.unpinnedItems.first?.isATab == true
            let tabsShouldScroll = !widthProvider.hasEnoughSpaceForAllTabs
            let hasUnpinnedTabs = sections.unpinnedItems.contains { $0.isATab }
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // Fixed Pinned Tabs
                    HStack(spacing: 0) {
                        let pinnedItems = sections.pinnedItems
                        ForEach(Array(pinnedItems.enumerated()), id: \.1.id) { (index, item) in
                            renderItem(item, index: index, selectedIndex: selectedIndex, isSingle: false,
                                       canScroll: tabsShouldScroll, widthProvider: widthProvider)
                        }
                        if pinnedItems.count > 0 {
                            separator
                                .padding(.leading, 6)
                                .padding(.trailing, 4)
                                .opacity(shouldShowSectionSeparator(tabsSections: sections) ? 1 : 0)
                        }
                    }
                    .animation(isAnimatingDrop || isDraggingATab ? nil : BeamAnimation.spring(stiffness: 400, damping: 30), value: sections.pinnedItems.count)
                    // Scrollable Tabs
                    GeometryReader { scrollContainerProxy in
                        let singleTabCenteringAdjustment = hasSingleOtherTab ? calculateSingleTabAdjustment(scrollContainerProxy) : 0
                        TrackableScrollView(tabsShouldScroll ? .horizontal : .init(), showIndicators: false, contentOffset: $scrollOffset, contentSize: $scrollContentSize) {
                            ScrollViewReader { scrollproxy in
                                HStack(spacing: 0) {
                                    let otherItems = sections.unpinnedItems
                                    let startIndex = sections.pinnedItems.count
                                    ForEach(Array(otherItems.enumerated()), id: \.1.id) { (index, item) in
                                        renderItem(item, index: startIndex + index, selectedIndex: selectedIndex, isSingle: hasSingleOtherTab,
                                                   canScroll: tabsShouldScroll, widthProvider: widthProvider, centeringAdjustment: singleTabCenteringAdjustment)
                                        .onAppear {
                                            guard tabsShouldScroll && startIndex+index == selectedIndex, let tab = item.tab else { return }
                                            DispatchQueue.main.async {
                                                scrollToTabIfNeeded(tab, containerGeometry: geometry, scrollViewProxy: scrollproxy)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: .infinity)
                                .background(hasUnpinnedTabs ? nil : GeometryReader { _ in
                                    Color.clear.preference(key: CurrentTabGlobalFrameKey.self, value: .init(index: selectedIndex, frame: .zero))
                                })
                                .onAppear {
                                    viewModel.singleTabCenteringAdjustment = singleTabCenteringAdjustment
                                    guard tabsShouldScroll, let currentTab = currentTab, !currentTab.isPinned else { return }
                                    scrollToTabIfNeeded(currentTab, containerGeometry: geometry, scrollViewProxy: scrollproxy, animated: false)
                                }
                                .onChange(of: singleTabCenteringAdjustment) { newValue in
                                    viewModel.singleTabCenteringAdjustment = newValue
                                }
                                .animation(isAnimatingDrop || isDraggingATab ? nil : BeamAnimation.spring(stiffness: 400, damping: 30), value: sections.unpinnedItems.count)
                            }
                        }
                        .if(tabsShouldScroll) {
                            $0.mask(scrollMask)
                                .overlay(sections.pinnedItems.count == 0 ? separator : nil, alignment: .leading)
                                .overlay(separator, alignment: .trailing)
                        }
                        .onHover { h in
                            guard !h else { return }
                            hoveredIndex = nil
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                // Dragged Tab over
                draggedItem
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(// use this to debug the draggable area
//                Path(draggableContentPath(geometry: geometry)).stroke(Color.red)
//            )
            .contentShape(
                // limit the drag gesture space
                Path(draggableContentPath(geometry: geometry))
            )
            .simultaneousGesture(
                // removing the drag gesture completely otherwise it is never stopped by the external drag
                isChangingTabsCountWhileHovering || externalDragModel.isDraggingTabOutside || externalDragModel.isDroppingAnExternalTab ? nil :
                    DragGesture(minimumDistance: 1)
                    .onChanged {
                        let gestureValue = TabGestureValue(startLocation: $0.startLocation, location: $0.location, time: $0.time)
                        dragGestureOnChange(gestureValue: gestureValue, containerGeometry: geometry)
                    }
                    .onEnded {
                        let gestureValue = TabGestureValue(startLocation: $0.startLocation, location: $0.location, time: $0.time)
                        dragGestureOnEnded(gestureValue: gestureValue)
                    }
            )
            .onDrop(of: [UTType.beamBrowserTab], delegate: TabsExternalDropDelegate(withHandler: self, containerGeometry: geometry))
            .onAppear {
                startOtherMouseDownMonitor()
                externalDragModel.setup(withState: state, tabsMananger: browserTabsManager)
                updateDraggableTabsAreas(with: geometry, tabsSections: sections, widthProvider: widthProvider, singleTabFrame: viewModel.singleTabCurrentFrame, lastItemFrame: viewModel.lastItemCurrentFrame)
                contextMenuManager = .init(state: state)
            }
            .onDisappear {
                removeMouseMonitors()
                updateDraggableTabsAreas(with: nil, tabsSections: sections, widthProvider: widthProvider)
            }
            .onPreferenceChangeDebounced(CurrentTabGlobalFrameKey.self, delay: .milliseconds(500)) { [weak state] newValue in
                currentTabFrameDidChange(newValue: newValue, state: state, hasUnpinnedTabs: hasUnpinnedTabs,
                                         geometry: geometry, widthProvider: widthProvider)
            }
            .onPreferenceChangeDebounced(SingleTabGlobalFrameKey.self, delay: .milliseconds(500)) { newValue in
                importantTabFrameDidChange(newValue: newValue, isSingle: true, geometry: geometry, widthProvider: widthProvider)
            }
            .onPreferenceChangeDebounced(LastTabGlobalFrameKey.self, delay: .milliseconds(500)) { newValue in
                importantTabFrameDidChange(newValue: newValue, isLast: true, geometry: geometry, widthProvider: widthProvider)
            }
            .onChange(of: widthProvider.computedFixedWidths) { _ in
                guard browserTabsManager.currentTabUIFrame == .zero else { return }
                updateDraggableTabsAreas(with: nil, tabsSections: sections, widthProvider: widthProvider)
            }
            .onChange(of: sections.allItems.count) { _ in
                if sections.unpinnedItems.count <= 1 {
                    updateDraggableTabsAreas(with: nil, tabsSections: sections, widthProvider: widthProvider)
                }
                guard hoveredIndex != nil else { return }
                isChangingTabsCountWhileHovering = true
                startTrackingMouseMove()
            }
        }
    }

}

// MARK: - Actions
extension TabsListView {
    private func updateDraggableTabsAreas(with geometry: GeometryProxy?, tabsSections: TabsListItemsSections,
                                          widthProvider: TabsListWidthProvider, singleTabFrame: CGRect? = nil, lastItemFrame: CGRect? = nil) {
        guard let geometry = geometry else {
            draggableTabsAreas = []
            return
        }
        var globalFrame = geometry.safeTopLeftGlobalFrame(in: nil)
        globalFrame.origin.y = 12
        globalFrame.size.height = TabView.height

        var areas: [CGRect] = []
        var pinnedFrame: CGRect = .zero
        if tabsSections.pinnedItems.count > 0 {
            pinnedFrame = globalFrame
            pinnedFrame.size.width = widthProvider.widthForAllPinnedItems(pinnedItemsCount: tabsSections.pinnedItems.count,
                                                                          includeSpaceBetweenPinnedAndOther: false)
            areas.append(pinnedFrame)
        }
        if tabsSections.unpinnedItems.count == 1, let singleTabFrame = singleTabFrame {
            areas.append(singleTabFrame)
        } else if tabsSections.unpinnedItems.count != 0 {
            if tabsSections.unpinnedItems.contains(where: { $0.isATab }) {
                if let lastItemFrame = lastItemFrame {
                    var frame = globalFrame
                    frame.size.width = lastItemFrame.maxX - globalFrame.minX
                    areas = [frame]
                } else {
                    areas = [globalFrame]
                }
            } else {
                let itemsWidth = tabsSections.unpinnedItems.reduce(0, { partialResult, item in
                    return partialResult + widthProvider.width(forItem: item, selected: false, pinned: false)
                })
                let pinnedMaxX = pinnedFrame.maxX + (pinnedFrame != .zero ? widthProvider.separatorBetweenPinnedAndOther : 0)
                let itemsMinX = max(globalFrame.minX, pinnedMaxX)
                let itemsArea = CGRect(x: itemsMinX, y: globalFrame.minY, width: itemsWidth, height: globalFrame.height)
                areas.append(itemsArea)
            }
        }
        draggableTabsAreas = areas
    }

    private func draggableContentPath(geometry: GeometryProxy) -> CGPath {
        let path: CGMutablePath
        if draggableTabsAreas.isEmpty {
            path = CGMutablePath(rect: CGRect(x: 0, y: 12, width: geometry.size.width, height: TabView.height), transform: nil)
        } else {
            path = CGMutablePath()
            let relativeOrigin = geometry.safeTopLeftGlobalFrame(in: nil).origin
            draggableTabsAreas.forEach { r in
                var addRect = r
                addRect.origin.x -= relativeOrigin.x
                addRect.origin.y -= relativeOrigin.y
                path.addRect(addRect)
            }
        }
        return path
    }

    private func onTabTouched(at index: Int) {
        guard !isDraggingATab, selectedIndex != index else {
            viewModel.lastTouchWasOnUnselectedTab = false
            return
        }
        viewModel.lastTouchWasOnUnselectedTab = true
        if let tab = sections.allItems[index].tab {
            browserTabsManager.setCurrentTab(tab)
        }
    }

    private func onTabTapped(at index: Int, isRightMouse: Bool, event: NSEvent?) {
        if isRightMouse {
            onTabRightClick(at: index, event: event)
            return
        }
        guard !isDraggingATab, selectedIndex == index, !viewModel.lastTouchWasOnUnselectedTab else { return }
        state.startFocusOmnibox(fromTab: true)
    }

    private func onTabRightClick(at index: Int, event: NSEvent?) {
        guard let tab = sections.allItems[index].tab else { return }
        contextMenuManager?.showContextMenu(forTab: tab, atListIndex: index, sections: sections, event: event,
                                            onCloseItem: { _ in
            onItemClose(at: index, fromContextMenu: true)
        })
    }

    private func startTrackingMouseMove() {
        guard viewModel.mouseMoveMonitor == nil else { return }
        viewModel.mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
            isChangingTabsCountWhileHovering = false
            if let monitor = viewModel.mouseMoveMonitor {
                NSEvent.removeMonitor(monitor)
                viewModel.mouseMoveMonitor = nil
            }
            return $0
        } as AnyObject?
    }

    private func startOtherMouseDownMonitor() {
        guard viewModel.otherMouseDownMonitor == nil else { return }
        viewModel.otherMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { event in
            guard let index = hoveredIndex else { return event }
            if event.buttonNumber == 2 {
                onItemClose(at: index)
            }
            return event
        } as AnyObject?
    }

    private func removeMouseMonitors() {
        if let mouseMoveMonitor = viewModel.mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
        }

        if let otherMouseDownMonitor = viewModel.otherMouseDownMonitor {
            NSEvent.removeMonitor(otherMouseDownMonitor)
        }
    }

    private func onItemClose(at index: Int, fromContextMenu: Bool = false) {
        guard let tabIndex = browserTabsManager.tabIndex(forListIndex: index) else { return }
        state.closeTab(tabIndex, allowClosingPinned: fromContextMenu)
    }

    private func onItemCopy(at index: Int) {
        guard index < sections.allItems.count else { return }
        let tab = sections.allItems[index].tab
        tab?.copyURLToPasteboard()
    }

    private func onTabToggleMute(at index: Int) {
        guard index < sections.allItems.count else { return }
        let tab = sections.allItems[index].tab
        tab?.mediaPlayerController?.toggleMute()
    }

    private func onFileDrop(at index: Int, url: URL) {
        guard index < sections.allItems.count, let tab = sections.allItems[index].tab else { return }
        guard BeamUniformTypeIdentifiers.supportsNavigation(toLocalFileURL: url) else { return }
        tab.state?.navigateTab(tab, toURLRequest: .init(url: url))
    }

    private func tabViewId(for tab: BrowserTab) -> String {
        return "browserTab-\(tab.id)"
    }

    private func accessibilityIdentifier(for item: TabsListItem) -> String {
        var groupSuffix = ""
        if let group = item.group {
            groupSuffix = "-Group(\(group.title ?? "untitled"))"
        }
        if item.isATab, let tab = item.tab {
            let pinSuffix = tab.isPinned ? "-pinned" : ""
            return "TabItem-BrowserTab\(pinSuffix)\(groupSuffix)-(\(tab.title))"
        } else if item.isAGroupCapsule, let group = item.group {
            let collapsedSuffix = group.collapsed ? "-collapsed" : ""
            return "TabItem-GroupCapsule\(groupSuffix)\(collapsedSuffix)-\(group.title ?? "untitled")"
        } else {
            return "TabItem-Unknown"
        }
    }

    private func scrollToTabIfNeeded(_ tab: BrowserTab,
                                     containerGeometry: GeometryProxy,
                                     scrollViewProxy: ScrollViewProxy,
                                     animated: Bool = true) {
        if animated {
            withAnimation {
                scrollViewProxy.scrollTo(tabViewId(for: tab))
            }
        } else {
            scrollViewProxy.scrollTo(tabViewId(for: tab))
        }
    }
}

// MARK: - Tab items frames handlers
extension TabsListView {
    private struct TabFrame: Equatable {
        var index: Int
        var frame: CGRect
    }
    private struct CurrentTabGlobalFrameKey: PreferenceKey {
        static func reduce(value: inout TabFrame?, nextValue: () -> TabFrame?) {
            value = nextValue() ?? value
        }
    }
    private struct LastTabGlobalFrameKey: FramePreferenceKey {}
    struct SingleTabGlobalFrameKey: FramePreferenceKey {}

    private func importantTabFrameDidChange(newValue: CGRect?, isSingle: Bool = false, isLast: Bool = false,
                                            geometry: GeometryProxy?, widthProvider: TabsListWidthProvider) {
        guard (isSingle || isLast) && !isDraggingATab else { return }
        if isSingle {
            viewModel.singleTabCurrentFrame = newValue
        } else if isLast {
            viewModel.lastItemCurrentFrame = newValue
        }
        guard let newValue = newValue else { return }
        updateDraggableTabsAreas(with: geometry, tabsSections: sections, widthProvider: widthProvider,
                                 singleTabFrame: isSingle ? newValue : viewModel.singleTabCurrentFrame,
                                 lastItemFrame: isLast ? newValue : viewModel.lastItemCurrentFrame)
    }
    private func currentTabFrameDidChange(newValue: TabFrame?, state: BeamState?, hasUnpinnedTabs: Bool,
                                          geometry: GeometryProxy?, widthProvider: TabsListWidthProvider) {
        guard !isDraggingATab && newValue != nil else { return }
        guard newValue?.index == selectedIndex else { return }
        state?.browserTabsManager.currentTabUIFrame = newValue?.frame
        guard !isSingleTab(atIndex: selectedIndex, in: sections) || !hasUnpinnedTabs else { return }
        updateDraggableTabsAreas(with: geometry, tabsSections: sections, widthProvider: widthProvider,
                                 singleTabFrame: viewModel.singleTabCurrentFrame, lastItemFrame: viewModel.lastItemCurrentFrame)
    }
}

// MARK: - After Drag methods
extension TabsListView {
    private func moveItem(from currentIndex: Int, to newIndex: Int, inGroup group: TabGroup?) {
        browserTabsManager.moveListItem(atListIndex: currentIndex, toListIndex: newIndex, changeGroup: group)
    }

    private func updatePinTabAfterDrag(_ tab: BrowserTab, shouldBePinned: Bool) {
        tab.isPinned = shouldBePinned
        if shouldBePinned {
            browserTabsManager.pinTab(tab)
        } else {
            browserTabsManager.unpinTab(tab)
        }
    }
}

// MARK: - Drag Gesture Handler
extension TabsListView {

    private func index(of tab: BrowserTab) -> Int? {
        browserTabsManager.listItems.allItems.firstIndex { $0.tab == tab }
    }

    /// A drag is allowed to leave the window when the mouse leaves the ToolBar (horizontaly or vertically)
    /// and if this is not a pinned tab (pin tabs are present on every window, it doesn't make sense to change their window)
    private func shouldStartExternalDrag(for tab: BrowserTab, atLocation location: CGPoint, inContainer containerGeometry: GeometryProxy) -> Bool {
        guard !externalDragModel.isDraggingTabOutside && !tab.isPinned else { return false }
        let horizontalThreshold: CGFloat = 30
        return location.y < 0 || location.y > Toolbar.height
        || location.x < -horizontalThreshold
        || location.x > containerGeometry.size.width + horizontalThreshold
    }

    private func dragGestureOnChange(gestureValue: TabGestureValue, containerGeometry: GeometryProxy) {
        guard let currentTab = currentTab else { return }
        if dragModel.dragStartIndex == nil {
            guard let currentTabIndex = index(of: currentTab) else { return }

            let sections = externalDragModel.isDroppingAnExternalTab ? browserTabsManager.listItems : sections
            viewModel.firstDragGestureValue = gestureValue
            let widthProvider = widthProvider(for: containerGeometry, sections: sections)
            dragModel.prepareForDrag(gestureValue: gestureValue, scrollContentOffset: scrollOffset,
                                     currentItemIndex: currentTabIndex, sections: sections,
                                     singleTabCenteringAdjustment: viewModel.singleTabCenteringAdjustment, widthProvider: widthProvider)
            viewModel.currentDragDidChangeCurrentTab = false
            defer {
                externalDragModel.prepareExternalDraggingOfcurrentTab(atLocation: gestureValue.location)
            }

            if let newStartIndex = dragModel.dragStartIndex, newStartIndex != currentTabIndex {
                let draggedItem = sections.allItems[newStartIndex]
                guard let tab = draggedItem.tab else {
                    // Probably tried to drag a group capsule. We stop the drag gesture here.
                    dragModel.cleanAfterDrag()
                    return
                }
                viewModel.currentDragDidChangeCurrentTab = true
                browserTabsManager.setCurrentTab(tab)
                return
            }
        }
        dragModel.dragGestureChanged(gestureValue: gestureValue,
                                     scrollContentOffset: scrollOffset,
                                     containerGeometry: containerGeometry)
        let location = gestureValue.location
        if shouldStartExternalDrag(for: currentTab, atLocation: location, inContainer: containerGeometry) {
            startExternalDragging(atLocation: location)
        }
    }

    private func dragGestureOnEnded(gestureValue: TabGestureValue) {
        defer {
            externalDragModel.clearExternalDragging()
        }
        guard let currentTab = currentTab,
              let dragStartIndex = self.dragModel.dragStartIndex,
              let firstGestureValue = viewModel.firstDragGestureValue,
              let draggingOverIndex = self.dragModel.draggingOverIndex else { return }
        let timeSinceStart = gestureValue.time.timeIntervalSince(firstGestureValue.time)
        if timeSinceStart < 0.05 {
            // it was just a quick tap
            self.dragModel.cleanAfterDrag()
            if !viewModel.currentDragDidChangeCurrentTab {
                state.startFocusOmnibox(fromTab: true)
            }
        } else {
            let shouldBePinned = self.dragModel.draggingOverPins
            self.isAnimatingDrop = true
            let dropAnimationDuration = 0.2
            withAnimation(.interactiveSpring()) {
                self.dragModel.dragGestureEnded(scrollContentOffset: scrollOffset)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + dropAnimationDuration) {
                self.moveItem(from: dragStartIndex, to: draggingOverIndex, inGroup: dragModel.draggingOverGroup)
                if shouldBePinned != currentTab.isPinned {
                    self.updatePinTabAfterDrag(currentTab, shouldBePinned: shouldBePinned)
                }
                self.dragModel.cleanAfterDrag()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.externalDragModel.isDroppingAnExternalTab = false
                    self.isAnimatingDrop = false
                }
            }
        }
    }
}

// MARK: - External Drop Handler
extension TabsListView: TabsExternalDropDelegateHandler {

    private func startExternalDragging(atLocation: CGPoint) {
        externalDragModel.startExternalDraggingOfCurrentTab(atLocation: atLocation)
        dragModel.cleanAfterDrag()
    }

    func onDropStarted(location: CGPoint, startLocation: CGPoint, containerGeometry: GeometryProxy) {
        if let tab = state.data.currentDraggingSession?.draggedObject as? BrowserTab {
            // Temporarily add the tab to the end of the tabs
            // then ask the dragModel to calculate what would be the actual insert index
            // then move the tab to the correct index and get the starting location
            // then reset the dragModel to be correctly setup in the next drop gesture move.
            browserTabsManager.setCurrentTab(tab)
            if !browserTabsManager.tabs.contains(tab) {
                browserTabsManager.tabs.append(tab)
            }
            let sections = state.browserTabsManager.listItems
            let gestureValue = TabGestureValue(startLocation: startLocation, location: location, time: BeamDate.now)
            let currentTabIndex = index(of: tab) ?? sections.allItems.count
            let item = sections.allItems.first { $0.tab == tab }
            let widthProvider = widthProvider(for: containerGeometry, sections: sections)
            dragModel.prepareForDrag(gestureValue: gestureValue, scrollContentOffset: scrollOffset,
                                     currentItemIndex: currentTabIndex, sections: sections,
                                     singleTabCenteringAdjustment: viewModel.singleTabCenteringAdjustment, widthProvider: widthProvider)
            let insertIndex = dragModel.dragStartIndex ?? currentTabIndex
            state.browserTabsManager.moveListItem(atListIndex: currentTabIndex, toListIndex: insertIndex, changeGroup: item?.group)

            var startLocation = startLocation
            startLocation.x = dragModel.frameForItemAtIndex(insertIndex).midX
            externalDragModel.dropOfExternalTabStarted(atLocation: startLocation)
            dragModel.cleanAfterDrag()
        }
    }

    func onDropUpdated(location: CGPoint, startLocation: CGPoint, containerGeometry: GeometryProxy) {
        guard externalDragModel.isDroppingAnExternalTab else { return }
        let startLocation = externalDragModel.dropStartLocation ?? startLocation
        let gestureValue = TabGestureValue(startLocation: startLocation, location: location, time: BeamDate.now)
        dragGestureOnChange(gestureValue: gestureValue, containerGeometry: containerGeometry)
    }

    func onDropEnded(location: CGPoint, startLocation: CGPoint, cancelled: Bool, containerGeometry: GeometryProxy) {
        guard externalDragModel.isDroppingAnExternalTab else { return }
        guard let tab = state.data.currentDraggingSession?.draggedObject as? BrowserTab else {
            return
        }

        guard !cancelled else {
            externalDragModel.dropOfExternalTabExitedWindow(tab: tab)
            dragModel.cleanAfterDrag()
            return
        }
        let startLocation = externalDragModel.dropStartLocation ?? startLocation
        let gestureValue = TabGestureValue(startLocation: startLocation, location: location, time: BeamDate.now)
        dragGestureOnEnded(gestureValue: gestureValue)
    }

}

// MARK: - SwiftUI Preview
struct TabsListView_Previews: PreviewProvider {
    static var state = BeamState()

    static func tab(_ title: String) -> BrowserTab {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: try! BeamNote(title: "note"))
        t.title = title
        return t
    }
    static var currentab: BrowserTab = {
        return tab("Current")
    }()
    static var sections: TabsListItemsSections {
        let tabs = [
            tab("Test"), tab("Test"), tab("Test"),
            currentab,
            tab("Test"), tab("Test"), tab("Test")
        ]
        let items = tabs.map { TabsListItem(tab: $0, group: nil) }
        return TabsListItemsSections(allItems: items, pinnedItems: [], unpinnedItems: items)
    }
    static var previews: some View {
        TabsListView()
            .environmentObject(state)
            .frame(width: 500)
    }
}
