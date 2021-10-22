//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

private extension BrowserTab {
    var stackIdentifier: String {
        "tab\(isPinned ? "-pinned" : "")-\(id)"
    }
}

struct BrowserTabBar: View {
    @EnvironmentObject var state: BeamState

    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?

    @ObservedObject private var dragModel = BrowserTabBarDragModel()
    @State private var disableAnimation = false
    @State private var firstGestureValue: DragGesture.Value?
    @State private var enableScrollOffsetTracking = false

    private var isDraggingATab: Bool {
        return dragModel.draggingOverIndex != nil
    }

    private var emptySpacer: some View {
        BrowserTabView.BackgroundView(isSelected: false, isHovering: false)
            .overlay(Separator(hairline: true, color: BrowserTabView.separatorColor)
                        .padding(.vertical, 7),
                     alignment: .trailing)
    }

    @State private var scrollOffset: CGFloat = 0
    @State private var isHoveringScrollView: Bool = false
    private let animationDuration = 0.3

    private var stackAnimation: Animation? {
        disableAnimation ? nil : BeamAnimation.easeInOut(duration: animationDuration)
    }

    func renderItem(tab: BrowserTab, index: Int, allowHover: Bool,
                    containerGeometry: GeometryProxy, scrollViewProxy: ScrollViewProxy?) -> some View {
        Group {
            let selected = isSelected(tab)
            let isTheDraggedTab = selected && isDraggingATab
            let dragStartIndex = dragModel.dragStartIndex ?? 0
            if index == dragModel.draggingOverIndex && index <= dragStartIndex {
                emptySpacer.frame(width: dragModel.widthForDraggingTab)
            }
            BrowserTabView(tab: tab,
                           isSelected: selected,
                           isDragging: isTheDraggedTab,
                           allowHover: allowHover,
                           onClose: {
                guard index < tabs.count else { return }
                let tab = tabs[index]
                onTabClose(tab)
            })
                .zIndex(selected ? 1 : 0)
                .frame(width: isTheDraggedTab ? 0 :
                        widthForTab(selected: selected, pinned: tab.isPinned, containerGeometry: containerGeometry))
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity))
                .disabled(isDraggingATab && !selected)
                .opacity(isTheDraggedTab ? 0 : 1)
                .onAppear {
                    guard selected, let proxy = scrollViewProxy else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        scrollToTabIfNeeded(tab, containerGeometry: containerGeometry, scrollViewProxy: proxy)
                    }
                }
                .contextMenu {
                    Button("\(tab.isPinned ? "Unpin" : "Pin") Tab") {
                        if tab.isPinned {
                            state.browserTabsManager.unpinTab(tab)
                        } else {
                            state.browserTabsManager.pinTab(tab)
                        }
                    }.disabled(!tab.isPinned && tab.url == nil)
                    Button("Close Tab") {
                        guard index < tabs.count else { return }
                        let tab = tabs[index]
                        onTabClose(tab, fromContextMenu: true)
                    }
                }
            if index == dragModel.draggingOverIndex && index > dragStartIndex {
                emptySpacer.frame(width: dragModel.widthForDraggingTab)
            }
        }
    }

    private var tabsSections: (pinnedTabs: [BrowserTab], otherTabs: [BrowserTab]) {
        guard let firstUnpinnedIndex = tabs.firstIndex(where: { !$0.isPinned }) else {
            return (tabs, [])
        }
        guard firstUnpinnedIndex > 0 else { return ([], tabs) }
        return (Array(tabs[0..<firstUnpinnedIndex]), Array(tabs[firstUnpinnedIndex..<tabs.count]))
    }

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    let tabsSections = tabsSections
                    HStack(spacing: 0) {
                        // Fixed Pinned Tabs
                        HStack(spacing: 0) {
                            let pinnedTabs = tabsSections.pinnedTabs
                            ForEach(Array(zip(pinnedTabs.indices, pinnedTabs)), id: \.1.stackIdentifier) { (index, tab) in
                                renderItem(tab: tab, index: index, allowHover: true,
                                           containerGeometry: geometry, scrollViewProxy: nil)
                            }
                        }
                        // Scrollable Tabs
                        TrackableScrollView(.horizontal, showIndicators: false, contentOffset: $scrollOffset) {
                            ScrollViewReader { proxy in
                                HStack(spacing: 0) {
                                    let otherTabs = tabsSections.otherTabs
                                    let startIndex = tabs.count - otherTabs.count
                                    ForEach(Array(zip(otherTabs.indices, otherTabs)), id: \.1.stackIdentifier) { (index, tab) in
                                        renderItem(tab: tab, index: startIndex + index, allowHover: isHoveringScrollView,
                                                   containerGeometry: geometry, scrollViewProxy: proxy)
                                    }
                                }
                                .onAppear {
                                    guard let currentTab = currentTab, !currentTab.isPinned else { return }
                                    scrollToTabIfNeeded(currentTab, containerGeometry: geometry, scrollViewProxy: proxy, animated: false)
                                    DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(500))) {
                                        self.enableScrollOffsetTracking = true
                                    }
                                }
                            }
                        }
                        .onHover { isHoveringScrollView = $0 }
                        .frame(maxWidth: .infinity)
                    }
                    .animation(stackAnimation, value: tabsSections.pinnedTabs)
                    .animation(stackAnimation, value: tabsSections.otherTabs)
                    .animation(stackAnimation, value: dragModel.offset)
                    .animation(stackAnimation, value: dragModel.draggingOverIndex)

                    // Dragging Tab
                    if let currentTab = currentTab, isDraggingATab {
                        BrowserTabView(tab: currentTab, isSelected: true, isDragging: true)
                            .offset(x: dragModel.offset.x, y: dragModel.offset.y)
                            .frame(width: dragModel.widthForDraggingTab)
                            .transition(.asymmetric(insertion: .identity, removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.1))))
                            .animation(.interactiveSpring(), value: dragModel.offset)
                    }
                }
                .frame(maxWidth: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragGestureOnChange(gestureValue: $0, containerGeometry: geometry) }
                        .onEnded { dragGestureOnEnded(gestureValue: $0) }
                )
            }
            BrowserNewTabView {
                state.startNewSearch()
            }
        }
        .frame(height: 28)
        .background(
            BeamColor.ToolBar.secondaryBackground.swiftUI
                .overlay(Rectangle()
                            .fill(BeamColor.ToolBar.shadowBottom.swiftUI)
                            .frame(height: Separator.hairlineHeight),
                         alignment: .bottom)
                .shadow(color: Color.black.opacity(0.04), radius: 7, x: 0, y: 2)
        )
        .animation(nil)
    }

    private func dragGestureOnChange(gestureValue: DragGesture.Value,
                                     containerGeometry: GeometryProxy) {
        guard let currentTab = currentTab else { return }
        if dragModel.dragStartIndex == nil {
            firstGestureValue = gestureValue
            let currentTabIndex = position(of: currentTab)
            dragModel.prepareForDrag(gestureValue: gestureValue,
                                     scrollContentOffset: scrollOffset,
                                     currentTabIndex: currentTabIndex,
                                     tabsCount: tabs.count,
                                     pinnedTabsCount: tabs.filter { $0.isPinned }.count,
                                     tabWidthBuilder: { selected, pinned in
                                        widthForTab(selected: selected, pinned: pinned, containerGeometry: containerGeometry)
                                     })
            if let newStartIndex = dragModel.dragStartIndex, newStartIndex != currentTabIndex {
                self.currentTab = tabs[newStartIndex]
                return
            } else {
                // first pass, let's setup dragged view without animation
                disableAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.disableAnimation = false
                }
            }
        }
        dragModel.dragGestureChanged(gestureValue: gestureValue,
                                     scrollContentOffset: scrollOffset,
                                     containerGeometry: containerGeometry)
    }

    private func dragGestureOnEnded(gestureValue: DragGesture.Value) {
        guard let currentTab = currentTab,
              let dragStartIndex = self.dragModel.dragStartIndex,
              let draggingOverIndex = self.dragModel.draggingOverIndex else { return }

        if let firstGestureValue = firstGestureValue,
           gestureValue.time.timeIntervalSince(firstGestureValue.time) < 0.05 {
            // it was just a quick tap
            self.dragModel.cleanAfterDrag()
        } else {
            let shouldBePinned = self.dragModel.draggingOverPins
            self.dragModel.dragGestureEnded(scrollContentOffset: scrollOffset)
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                self.disableAnimation = true
                self.moveTabs(from: dragStartIndex, to: draggingOverIndex, with: currentTab)
                self.updatePinTabAfterDrag(currentTab, shouldBePinned: shouldBePinned)
                self.dragModel.cleanAfterDrag()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.disableAnimation = false
                }
            }
        }
    }

    private func onTabClose(_ tab: BrowserTab, fromContextMenu: Bool = false) {
        let tabIndex = position(of: tab)
        state.closedTab(tabIndex, allowClosingPinned: fromContextMenu)
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func position(of tab: BrowserTab) -> Int {
        return tabs.firstIndex(of: tab) ?? 0
    }

    private func pinnedTabs() -> [BrowserTab] {
        tabs.filter { $0.isPinned }
    }

    private func widthForTab(selected: Bool, pinned: Bool, containerGeometry: GeometryProxy) -> CGFloat {
        guard !pinned else { return BrowserTabView.pinnedWidth }
        var pinnedTabsCount = pinnedTabs().count
        if dragModel.draggingOverPins && currentTab?.isPinned != true {
            pinnedTabsCount += 1
        } else if dragModel.draggingOverIndex != nil && !dragModel.draggingOverPins && currentTab?.isPinned == true {
            pinnedTabsCount -= 1
        }
        let availableWidth = containerGeometry.size.width - (CGFloat(pinnedTabsCount) * BrowserTabView.pinnedWidth)
        let unpinnedTabsCount = tabs.count - pinnedTabsCount
        guard unpinnedTabsCount > 0 else { return availableWidth }
        var tabWidth = availableWidth / CGFloat(unpinnedTabsCount)
        if tabWidth < BrowserTabView.minimumActiveWidth {
            // not enough space for all tabs
            tabWidth = (availableWidth - BrowserTabView.minimumActiveWidth) / CGFloat(unpinnedTabsCount - 1)
        }
        return max(selected ? BrowserTabView.minimumActiveWidth : BrowserTabView.minimumWidth, tabWidth)
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

    private func scrollToTabIfNeeded(_ tab: BrowserTab,
                                     containerGeometry: GeometryProxy,
                                     scrollViewProxy: ScrollViewProxy,
                                     animated: Bool = true) {
        let index = position(of: tab)
        let tabWidth = widthForTab(selected: isSelected(tab), pinned: tab.isPinned, containerGeometry: containerGeometry)
        let tabOriginX = CGFloat(index) * widthForTab(selected: false, pinned: false, containerGeometry: containerGeometry)
        let point = CGPoint(x: tabOriginX + tabWidth, y: 0)
        let outOfBoundsWidth = point.x - (containerGeometry.size.width + scrollOffset)
        guard outOfBoundsWidth > 0 else { return }
        if animated {
            withAnimation {
                scrollViewProxy.scrollTo("tab-\(tab.id)")
            }
        } else {
            scrollViewProxy.scrollTo("tab-\(tab.id)")
        }
    }

}

struct BrowserTabBar_Previews: PreviewProvider {
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
        BrowserTabBar(tabs: .constant([
            tab("Test"), tab("Test"), tab("Test"),
            currentab,
            tab("Test"), tab("Test"), tab("Test")
        ]), currentTab: .constant(currentab))
        .environmentObject(state)
        .frame(width: 500)

    }
}
