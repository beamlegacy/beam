//
//  TabsListView.swift
//  Beam
//
//  Created by Remi Santos on 02/12/2021.
//
// swiftlint:disable file_length

import SwiftUI
import BeamCore

struct TabsListView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?
    var globalContainerGeometry: GeometryProxy?

    @ObservedObject private var dragModel = TabsDragModel()
    @State private var firstDragGestureValue: DragGesture.Value?
    @State private var disableAnimation: Bool = false
    @State private var isAnimatingDrop: Bool = false
    private let dropAnimationDuration = 0.2

    @State private var hoveredIndex: Int?
    @State private var isChangingTabsCountWhileHovering: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentSize: CGFloat = 0
    @State private var draggableTabsAreas: [CGRect] = [] {
        didSet {
            windowInfo.undraggableWindowRects = draggableTabsAreas
        }
    }

    @StateObject private var viewModel = ViewModel()
    private class ViewModel: ObservableObject {
        var currentDragDidChangeCurrentTab = false
        var lastTouchWasOnUnselectedTab: Bool = false
        var singleTabCenteringAdjustment: CGFloat = 0
        var singleTabCurrentFrame: CGRect?
        var mouseMoveMonitor: Any?

        deinit {
            if let monitor = mouseMoveMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    private var isDraggingATab: Bool {
        dragModel.draggingOverIndex != nil
    }

    private var selectedIndex: Int {
        guard let currentTab = currentTab else { return 0 }
        return tabs.firstIndex(of: currentTab) ?? 0
    }

    private func pinnedTabs() -> [BrowserTab] {
        tabs.filter { $0.isPinned }
    }

    private func widthProvider(for containerGeometry: GeometryProxy) -> TabsWidthProvider {
        TabsWidthProvider(tabsCount: tabs.count, pinnedTabsCount: pinnedTabs().count,
                         containerSize: containerGeometry.size, currentTabIsPinned: currentTab?.isPinned == true, dragModel: dragModel)
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

    private func shouldShowSectionSeparator(tabsSections: TabsSections) -> Bool {
        let hasSingleOtherTab = tabsSections.otherTabs.count == 1
        if let dragOverIndex = dragModel.draggingOverIndex {
            return !(dragModel.draggingOverPins == true && !dragModel.dragStartedFromPinnedTab && dragOverIndex == tabsSections.pinnedTabs.count)
        }
        return hasSingleOtherTab || (selectedIndex != tabsSections.pinnedTabs.count && hoveredIndex != tabsSections.pinnedTabs.count)
    }

    private func index(of tab: BrowserTab) -> Int {
        return tabs.firstIndex(of: tab) ?? 0
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func isSingleTab(atIndex: Int, in tabsSections: TabsSections) -> Bool {
        tabsSections.otherTabs.count == 1 && atIndex == tabsSections.pinnedTabs.count
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

    private func renderTab(_ tab: BrowserTab, index: Int, selectedIndex: Int, isSingle: Bool,
                           canScroll: Bool, widthProvider: TabsWidthProvider, centeringAdjustment: CGFloat = 0) -> some View {
        let selected = isSelected(tab)
        let id = tabViewId(for: tab)
        let isTheDraggedTab = selected && isDraggingATab
        let isTheLastTab = index == tabs.count - 1
        let dragStartIndex = dragModel.dragStartIndex ?? 0
        let showLeadingDragSpacer = index == dragModel.draggingOverIndex && index <= dragStartIndex
        let showTrailingDragSpacer = index == dragModel.draggingOverIndex && index > dragStartIndex
        let hideSeparator = tab.isPinned || (canScroll && isTheLastTab)
            || (!isDraggingATab && (selectedIndex == index + 1 || selectedIndex == index || hoveredIndex == index + 1 || hoveredIndex == index))
        let hueTint = state.browserTabsManager.tabsClusteringGroups[tab.id]?.hueTint
        return HStack(spacing: 0) {
            if showLeadingDragSpacer {
                emptyDragSpacer
                separator.opacity(hideSeparator ? 0 : 1)
            }
            TabView(tab: tab, isSelected: selected, isPinned: tab.isPinned, isSingleTab: isSingle, isDragging: isTheDraggedTab,
                    disableAnimations: isAnimatingDrop, disableHovering: isChangingTabsCountWhileHovering, hueTint: hueTint,
                    onTouchDown: { onTabTouched(at: index) },
                    onTap: { onTabTapped(at: index) },
                    onClose: { onTabClose(at: index) },
                    onCopy: { onTabCopy(at: index)},
                    onToggleMute: { onTabToggleMute(at: index) })
                .frame(width: isTheDraggedTab ? 0 : max(0, widthProvider.widthForTab(selected: selected, pinned: tab.isPinned) - centeringAdjustment))
                .opacity(isTheDraggedTab ? 0 : 1)
                .onHover { h in
                    if h { hoveredIndex = index }
                }
                .background(!selected ? nil : GeometryReader { prxy in
                    Color.clear.preference(key: CurrentTabGlobalFrameKey.self, value: .init(index: index, frame: prxy.safeTopLeftGlobalFrame(in: nil).rounded()))
                })
                .contextMenu { tabContextMenuItems(forTabAtIndex: index) }
            if !isSingle && !isTheDraggedTab {
                separator.opacity(hideSeparator ? 0 : 1)
            }
            if showTrailingDragSpacer {
                emptyDragSpacer
                separator.opacity(hideSeparator ? 0 : 1)
            }
        }
        .frame(height: TabView.height)
        .contentShape(Rectangle())
        .disabled(isDraggingATab && !isTheDraggedTab)
        .id(id)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
        .transition(tabTransition)
    }

    var body: some View {
        GeometryReader { geometry in
            let widthProvider = widthProvider(for: geometry)
            let tabsSections = buildTabsSections(with: tabs)
            let selectedIndex = selectedIndex
            let hasSingleOtherTab = tabsSections.otherTabs.count == 1
            let tabsShouldScroll = !widthProvider.hasEnoughSpaceForAllTabs
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // Fixed Pinned Tabs
                    HStack(spacing: 0) {
                        let pinnedTabs = tabsSections.pinnedTabs
                        ForEach(Array(zip(pinnedTabs.indices, pinnedTabs)), id: \.1) { (index, tab) in
                            renderTab(tab, index: index, selectedIndex: selectedIndex, isSingle: false,
                                      canScroll: tabsShouldScroll, widthProvider: widthProvider)
                        }
                        if pinnedTabs.count > 0 {
                            separator
                                .padding(.leading, 6)
                                .padding(.trailing, 4)
                                .opacity(shouldShowSectionSeparator(tabsSections: tabsSections) ? 1 : 0)
                        }
                    }
                    .if(isDraggingATab && dragModel.draggingOverPins) {
                        $0.animation(BeamAnimation.easeInOut(duration: 0.2), value: dragModel.draggingOverIndex)
                    }
                    .animation(isAnimatingDrop ? nil : BeamAnimation.spring(stiffness: 400, damping: 30), value: tabsSections.pinnedTabs.count)
                    // Scrollable Tabs
                    GeometryReader { scrollContainerProxy in
                        let singleTabCenteringAdjustment = hasSingleOtherTab ? calculateSingleTabAdjustment(scrollContainerProxy) : 0
                        TrackableScrollView(tabsShouldScroll ? .horizontal : .init(), showIndicators: false, contentOffset: $scrollOffset, contentSize: $scrollContentSize) {
                            ScrollViewReader { scrollproxy in
                                HStack(spacing: 0) {
                                    let otherTabs = tabsSections.otherTabs
                                    let startIndex = tabs.count - otherTabs.count
                                    ForEach(Array(zip(otherTabs.indices, otherTabs)), id: \.1) { (index, tab) in
                                        renderTab(tab, index: startIndex + index, selectedIndex: selectedIndex, isSingle: hasSingleOtherTab,
                                                  canScroll: tabsShouldScroll, widthProvider: widthProvider, centeringAdjustment: singleTabCenteringAdjustment)
                                            .onAppear {
                                                guard tabsShouldScroll && startIndex + index == selectedIndex else { return }
                                                DispatchQueue.main.async {
                                                    scrollToTabIfNeeded(tab, containerGeometry: geometry, scrollViewProxy: scrollproxy)
                                                }
                                            }
                                    }
                                }
                                .frame(maxHeight: .infinity)
                                .onAppear {
                                    viewModel.singleTabCenteringAdjustment = singleTabCenteringAdjustment
                                    guard tabsShouldScroll, let currentTab = currentTab, !currentTab.isPinned else { return }
                                    scrollToTabIfNeeded(currentTab, containerGeometry: geometry, scrollViewProxy: scrollproxy, animated: false)
                                }
                                .onChange(of: singleTabCenteringAdjustment) { newValue in
                                    viewModel.singleTabCenteringAdjustment = newValue
                                }
                                .if(isDraggingATab && !dragModel.draggingOverPins) {
                                    $0.animation(BeamAnimation.easeInOut(duration: 0.2), value: dragModel.draggingOverIndex)
                                }
                                .animation(isAnimatingDrop ? nil : BeamAnimation.spring(stiffness: 400, damping: 30), value: tabsSections.otherTabs.count)
                            }
                        }
                        .if(tabsShouldScroll) {
                            $0.mask(scrollMask)
                                .overlay(tabsSections.pinnedTabs.count == 0 ? separator : nil, alignment: .leading)
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
                if let currentTab = currentTab, isDraggingATab {
                    TabView(tab: currentTab, isSelected: true,
                            isPinned: dragModel.draggingOverPins,
                            isSingleTab: !dragModel.draggingOverPins && tabsSections.otherTabs.count <= 1,
                            isDragging: true)
                        .offset(x: dragModel.offset.x, y: dragModel.offset.y)
                        .frame(width: dragModel.widthForDraggingTab)
                        .transition(.asymmetric(insertion: .scale(scale: 0.98).animation(BeamAnimation.easeInOut(duration: 0.08)), removal: .opacity.combined(with: .scale(scale: 0.98)).animation(BeamAnimation.easeInOut(duration: 0.08))))
                        .animation(.interactiveSpring(), value: dragModel.offset)
                        .zIndex(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(
                // limit the drag gesture space
                Path(draggableContentPath(tabsSections: tabsSections, geometry: geometry))
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { dragGestureOnChange(gestureValue: $0, containerGeometry: geometry) }
                    .onEnded { dragGestureOnEnded(gestureValue: $0) }
            )
            .onAppear {
                updateDraggableTabsAreas(with: geometry, tabsSections: tabsSections)
            }
            .onDisappear {
                updateDraggableTabsAreas(with: nil, tabsSections: tabsSections)
            }
            .onPreferenceChange(CurrentTabGlobalFrameKey.self) { [weak state] newValue in
                guard !isDraggingATab && newValue != nil else { return }
                guard newValue?.index == selectedIndex else { return }
                state?.browserTabsManager.currentTabUIFrame = newValue?.frame
                guard !isSingleTab(atIndex: selectedIndex, in: tabsSections) else { return }
                updateDraggableTabsAreas(with: geometry, tabsSections: tabsSections, singleTabFrame: viewModel.singleTabCurrentFrame)
            }
            .onPreferenceChange(SingleTabGlobalFrameKey.self) { newValue in
                guard !isDraggingATab else { return }
                viewModel.singleTabCurrentFrame = newValue
                guard let newValue = newValue else { return }
                updateDraggableTabsAreas(with: geometry, tabsSections: tabsSections, singleTabFrame: newValue)
            }
            .onChange(of: tabs.count) { _ in
                guard hoveredIndex != nil else { return }
                isChangingTabsCountWhileHovering = true
                startTrackingMouseMove()
            }
        }
    }

    // MARK: - Actions
    private func updateDraggableTabsAreas(with geometry: GeometryProxy?, tabsSections: TabsSections, singleTabFrame: CGRect? = nil) {
        guard let geometry = geometry else {
            draggableTabsAreas = []
            return
        }
        var globalFrame = geometry.safeTopLeftGlobalFrame(in: nil)
        globalFrame.origin.y = 12
        globalFrame.size.height = TabView.height

        var areas: [CGRect] = []
        if tabsSections.pinnedTabs.count > 0 {
            var pinnedFrame = globalFrame
            pinnedFrame.size.width = CGFloat(tabsSections.pinnedTabs.count) * (TabView.pinnedWidth + 4)
            areas.append(pinnedFrame)
        }
        if tabsSections.otherTabs.count == 1, let singleTabFrame = singleTabFrame {
            areas.append(singleTabFrame)
        } else if tabsSections.otherTabs.count != 0 {
            areas = [globalFrame]
        }
        draggableTabsAreas = areas
    }

    private func draggableContentPath(tabsSections: TabsSections, geometry: GeometryProxy) -> CGPath {
        var path = CGMutablePath(rect: CGRect(x: 0, y: 12, width: geometry.size.width, height: TabView.height), transform: nil)
        if tabsSections.otherTabs.count <= 1 {
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
        state.browserTabsManager.currentTab = tabs[index]
    }

    private func onTabTapped(at index: Int) {
        guard !isDraggingATab, selectedIndex == index, !viewModel.lastTouchWasOnUnselectedTab else { return }
        state.startFocusOmnibox(fromTab: true)
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
        }
    }

    private func onTabClose(at index: Int, fromContextMenu: Bool = false) {
        state.closedTab(index, allowClosingPinned: fromContextMenu)
    }

    private func onTabCopy(at index: Int) {
        guard index < tabs.count else { return }
        let tab = tabs[index]
        tab.copyURLToPasteboard()
    }

    private func pasteAndGo(on tab: BrowserTab) {
        guard let query = NSPasteboard.general.string(forType: .string) else {  return }
        state.autocompleteManager.searchQuery = query
        state.omniboxInfo.wasFocusedFromTab = true
        state.startOmniboxQuery()
    }

    private func onTabToggleMute(at index: Int) {
        guard index < tabs.count else { return }
        let tab = tabs[index]
        tab.mediaPlayerController?.toggleMute()
    }

    typealias TabsSections = (pinnedTabs: [BrowserTab], otherTabs: [BrowserTab])
    private func buildTabsSections(with tabs: [BrowserTab]) -> TabsSections {
        guard let firstUnpinnedIndex = tabs.firstIndex(where: { !$0.isPinned }) else {
            return (tabs, [])
        }
        guard firstUnpinnedIndex > 0 else { return ([], tabs) }
        return (Array(tabs[0..<firstUnpinnedIndex]), Array(tabs[firstUnpinnedIndex..<tabs.count]))
    }

    private func tabViewId(for tab: BrowserTab) -> String {
        return "browserTab-\(tab.id)"
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

struct CurrentTabGlobalFrameKey: PreferenceKey {
    struct TabFrame: Equatable {
        var index: Int
        var frame: CGRect
    }
    static let defaultValue: TabFrame? = nil
    static func reduce(value: inout TabFrame?, nextValue: () -> TabFrame?) {
        value = nextValue() ?? value
    }
}

struct SingleTabGlobalFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

// MARK: - Context Menu Items
extension TabsListView {
    private func tabContextMenuItems(forTabAtIndex index: Int) -> some View {
        let tab = tabs[index]
        let firstGroup = Group {
            Button("Capture Page") {
                tab.collectTab()
            }.disabled(tab.url == nil || state.browserTabsManager.currentTab != tab || tab.isLoading)
            Button("Refresh Tab") {
                tab.reload()
            }.disabled(tab.url == nil)
            Button("Duplicate Tab") {
                state.duplicate(tab: tab)
            }
            Button("\(tab.isPinned ? "Unpin" : "Pin") Tab") {
                if tab.isPinned {
                    state.browserTabsManager.unpinTab(tab)
                } else {
                    state.browserTabsManager.pinTab(tab)
                }
            }.disabled(!tab.isPinned && tab.url == nil)
            Button(tab.mediaPlayerController?.isMuted == true ? "Unmute Tab" : "Mute Tab") {
                tab.mediaPlayerController?.toggleMute()
            }.disabled(tab.mediaPlayerController?.isPlaying != true)
        }
        let secondGroup = Group {
            Button("Copy Address") {
                tab.copyURLToPasteboard()
            }.disabled(tab.url == nil)
            Button("Paste and Go") {
                pasteAndGo(on: tab)
            }
        }

        return Group {
            firstGroup
            Divider()
            secondGroup
            Divider()
            contextMenuItemCloseGroup(forTabAtIndex: index)
            if Configuration.branchType == .develop {
                Divider()
                contextMenuItemDebugGroup()
            }
        }
    }

    private func contextMenuItemCloseGroup(forTabAtIndex index: Int) -> some View {
        Group {
            Button("Close Tab") {
                onTabClose(at: index, fromContextMenu: true)
            }
            Button("Close Other Tabs") {
                state.closeAllTabs(exceptedTabAt: index)
            }.disabled(tabs.allSatisfy({ $0.isPinned }) || tabs.count <= 1)
            Button("Close Tabs to the Right") {
                state.closeTabsToTheRight(of: index)
            }.disabled(index + 1 >= tabs.count || tabs.allSatisfy({ $0.isPinned }))
        }
    }

    private func contextMenuItemDebugGroup() -> some View {
        Group {
            if PreferencesManager.showTabsColoring {
                Button("Tab Grouping Feedback") {
                    AppDelegate.main.showTabGroupingFeedbackWindow(self)
                }
            }
        }
    }
}

// MARK: - Drag & Drop
extension TabsListView {

    fileprivate func dragGestureOnChange(gestureValue: DragGesture.Value,
                                         containerGeometry: GeometryProxy) {
        guard let currentTab = currentTab else { return }

        if dragModel.dragStartIndex == nil {
            firstDragGestureValue = gestureValue
            let currentTabIndex = index(of: currentTab)
            let pinnedCount = pinnedTabs().count
            let widthProvider = widthProvider(for: containerGeometry)
            dragModel.prepareForDrag(gestureValue: gestureValue, scrollContentOffset: scrollOffset,
                                     currentTabIndex: currentTabIndex, tabsCount: tabs.count, pinnedTabsCount: pinnedCount,
                                     singleTabCenteringAdjustment: viewModel.singleTabCenteringAdjustment, widthProvider: widthProvider)
            viewModel.currentDragDidChangeCurrentTab = false
            if let newStartIndex = dragModel.dragStartIndex, newStartIndex != currentTabIndex {
                viewModel.currentDragDidChangeCurrentTab = true
                self.currentTab = tabs[newStartIndex]
                return
            } else {
                viewModel.currentDragDidChangeCurrentTab = false
            }
        }
        dragModel.dragGestureChanged(gestureValue: gestureValue,
                                     scrollContentOffset: scrollOffset,
                                     containerGeometry: containerGeometry)
    }

    private func moveTabs(from currentIndex: Int, to index: Int, with tab: BrowserTab) {
        guard currentIndex != index else { return }
        // copying the array to trigger only one change
        var tabsArray = tabs
        tabsArray.remove(at: currentIndex)
        tabsArray.insert(tab, at: index.clamp(0, tabsArray.count))
        tabs = tabsArray
    }

    private func updatePinTabAfterDrag(_ tab: BrowserTab, shouldBePinned: Bool) {
        tab.isPinned = shouldBePinned
        if shouldBePinned {
            self.state.browserTabsManager.pinTab(tab)
        } else {
            self.state.browserTabsManager.unpinTab(tab)
        }
    }

    fileprivate func dragGestureOnEnded(gestureValue: DragGesture.Value) {
        guard let currentTab = currentTab,
              let dragStartIndex = self.dragModel.dragStartIndex,
              let firstGestureValue = firstDragGestureValue,
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
            self.dragModel.dragGestureEnded(scrollContentOffset: scrollOffset)
            DispatchQueue.main.asyncAfter(deadline: .now() + dropAnimationDuration) {
                    self.moveTabs(from: dragStartIndex, to: draggingOverIndex, with: currentTab)
                    self.updatePinTabAfterDrag(currentTab, shouldBePinned: shouldBePinned)
                    self.dragModel.cleanAfterDrag()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.isAnimatingDrop = false
                }
            }
        }
    }
}

// MARK: - SwiftUI Preview
struct TabsListView_Previews: PreviewProvider {
    static var state = BeamState()

    static func tab(_ title: String) -> BrowserTab {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, originMode: .today, note: BeamNote(title: "note"))
        t.title = title
        return t
    }
    static var currentab: BrowserTab = {
        return tab("Current")
    }()
    static var previews: some View {
        TabsListView(tabs: .constant([
            tab("Test"), tab("Test"), tab("Test"),
            currentab,
            tab("Test"), tab("Test"), tab("Test")
        ]), currentTab: .constant(currentab))
            .environmentObject(state)
            .frame(width: 500)
    }
}
