//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

private class BrowserTabBarDragModel: ObservableObject {
    @Published var offset = CGPoint.zero
    @Published var draggingOverIndex: Int?
    @Published var dragStartIndex: Int?

    var defaultTabWidth: CGFloat?
    var activeTabWidth: CGFloat?
    private var tabsCount: Int = 0

    func prepareForDrag(gestureValue: DragGesture.Value,
                        contentOffset: CGFloat,
                        currentTabIndex: Int,
                        tabsCount: Int,
                        tabWidth: CGFloat,
                        activeTabWidth: CGFloat) {

        self.tabsCount = tabsCount
        self.defaultTabWidth = tabWidth
        self.activeTabWidth = activeTabWidth
        // guess index
        let locationX = gestureValue.startLocation.x + contentOffset
        var tabIndex = Int((locationX / tabWidth).rounded(.down))
        if tabIndex > currentTabIndex {
            if locationX > tabWidth * CGFloat(currentTabIndex) + activeTabWidth {
                tabIndex = Int(((locationX - (activeTabWidth - tabWidth)) / tabWidth).rounded(.down))
            } else {
                tabIndex = currentTabIndex
            }
        }
        self.dragStartIndex = tabIndex.clamp(0, tabsCount - 1)
    }

    func cleanAfterDrag() {
        offset = .zero
        defaultTabWidth = nil
        activeTabWidth = nil
        draggingOverIndex = nil
        dragStartIndex = nil
        tabsCount = 0
    }

    func dragGestureChanged(gestureValue: DragGesture.Value, contentOffset: CGFloat, containerGeometry: GeometryProxy) {

        guard let defaultTabWidth = defaultTabWidth,
              let activeTabWidth = activeTabWidth,
              let dragStartIndex = dragStartIndex else { return }

        let locationX = gestureValue.location.x// + contentOffset
        let startLocationX = gestureValue.startLocation.x// + contentOffset
        let currentTabOrigin = CGFloat(dragStartIndex) * defaultTabWidth - startLocationX - contentOffset
        let offsetX = currentTabOrigin + locationX
        let offset = CGPoint(x: offsetX.clamp(0, containerGeometry.size.width - activeTabWidth), y: 0)

        var newDragIndex: Int?
        if let draggingOverIndex = self.draggingOverIndex {
            let currentIndex = CGFloat(draggingOverIndex)

            let thresoldL = currentIndex * defaultTabWidth
            let thresoldR = currentIndex * defaultTabWidth + activeTabWidth
            let gestureX = locationX + contentOffset
            if gestureX < thresoldL {
                newDragIndex = Int(currentIndex) - 1
            } else if gestureX > thresoldR {
                newDragIndex = Int(currentIndex) + 1
            }
        } else {
            newDragIndex = dragStartIndex
        }

        if let idx = newDragIndex {
            self.draggingOverIndex = idx.clamp(0, tabsCount - 1)
        }
        self.offset = offset
    }

    func dragGestureEnded(contentOffset: CGFloat) {
        guard let draggingOverIndex = draggingOverIndex, let defaultTabWidth = defaultTabWidth else { return }
        let x = CGFloat(draggingOverIndex) * defaultTabWidth - contentOffset
        offset = CGPoint(x: x, y: 0)
    }
}

struct BrowserTabBar: View {
    @EnvironmentObject var state: BeamState

    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?

    @ObservedObject private var dragModel = BrowserTabBarDragModel()
    @State private var disableAnimation = false
    @State private var firstGestureValue: DragGesture.Value?

    private var isDraggingATab: Bool {
        return dragModel.draggingOverIndex != nil
    }

    private var emptySpacer: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                Rectangle()
                    .fill(BeamColor.BottomBar.shadow.swiftUI)
                    .frame(height: 0.5)
                Spacer()
            }
            Separator(hairline: true).padding(.vertical, 7)
        }
    }

    @State private var scrollOffset: CGFloat = 0
    private let animationDuration = 0.3

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    TrackableScrollView(.horizontal, showIndicators: false, contentOffset: $scrollOffset) {
                        RetroCompatibleScrollViewReader { retroProxy in
                            HStack(spacing: 0) {
                                ForEach(Array(zip(tabs.indices, tabs)), id: \.1) { (index, tab) in
                                    let selected = isSelected(tab)
                                    let isTheDraggedTab = selected && isDraggingATab
                                    let dragStartIndex = dragModel.dragStartIndex ?? 0
                                    if index == dragModel.draggingOverIndex && index <= dragStartIndex {
                                        emptySpacer.frame(width: dragModel.activeTabWidth)
                                    }
                                    BrowserTabView(tab: tab,
                                                   isSelected: selected,
                                                   isDragging: isTheDraggedTab,
                                                   onClose: {
                                                    guard index < tabs.count else { return }
                                                    let tab = tabs[index]
                                                    onTabClose(tab)
                                                   })
                                        .zIndex(selected ? 1 : 0)
                                        .frame(width: isTheDraggedTab ? 0 :
                                                widthForTab(selected: selected, containerGeometry: geometry))
                                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .identity))
                                        .animation(disableAnimation ? nil : .easeInOut(duration: animationDuration))
                                        .disabled(isDraggingATab && !selected)
                                        .opacity(isTheDraggedTab ? 0 : 1)
                                        .onAppear {
                                            guard selected else { return }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                                                scrollToTabIfNeeded(tab, containerGeometry: geometry, scrollViewProxy: retroProxy)
                                            }
                                        }
                                    if index == dragModel.draggingOverIndex && index > dragStartIndex {
                                        emptySpacer.frame(width: dragModel.activeTabWidth)
                                    }
                                }
                            }
                            .onAppear {
                                guard let currentTab = currentTab else { return }
                                scrollToTabIfNeeded(currentTab, containerGeometry: geometry, scrollViewProxy: retroProxy, animated: false)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if let currentTab = currentTab, isDraggingATab {
                        // Let's add the dragging view on top
                        BrowserTabView(tab: currentTab, isSelected: true, isDragging: true)
                            .offset(x: dragModel.offset.x, y: dragModel.offset.y)
                            .frame(width: dragModel.activeTabWidth)
                            .animation(.easeInOut)
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
        .frame(height: 30)
        .background(
            BeamColor.Nero.swiftUI
                .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 0.5)
                .shadow(color: Color.black.opacity(0.04), radius: 7, x: 0, y: 2)
        )
        .animation(!state.windowIsResizing && !disableAnimation ? .easeInOut(duration: animationDuration) : nil)
    }

    private func dragGestureOnChange(gestureValue: DragGesture.Value,
                                     containerGeometry: GeometryProxy) {
        guard let currentTab = currentTab else { return }
        if dragModel.dragStartIndex == nil {
            firstGestureValue = gestureValue
            let currentTabIndex = position(of: currentTab)
            dragModel.prepareForDrag(gestureValue: gestureValue,
                                     contentOffset: scrollOffset,
                                     currentTabIndex: currentTabIndex,
                                     tabsCount: tabs.count,
                                     tabWidth: widthForTab(selected: false, containerGeometry: containerGeometry),
                                     activeTabWidth: widthForTab(selected: true, containerGeometry: containerGeometry))
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
                                     contentOffset: scrollOffset,
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
            withAnimation(.easeInOut(duration: animationDuration)) {
                self.dragModel.dragGestureEnded(contentOffset: scrollOffset)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                self.disableAnimation = true
                self.moveTabs(from: dragStartIndex, to: draggingOverIndex, with: currentTab)
                self.dragModel.cleanAfterDrag()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.disableAnimation = false
                }
            }
        }
    }

    private func onTabClose(_ tab: BrowserTab) {
        let tabIndex = position(of: tab)
        state.browserTabsManager.removeTab(tabIndex)
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func position(of tab: BrowserTab) -> Int {
        return tabs.firstIndex(of: tab) ?? 0
    }

    private func widthForTab(selected: Bool, containerGeometry: GeometryProxy) -> CGFloat {
        var tabWidth = containerGeometry.size.width / CGFloat(tabs.count)
        if tabWidth < BrowserTabView.minimumActiveWidth {
            // not enough space for all tabs
            tabWidth = (containerGeometry.size.width - BrowserTabView.minimumActiveWidth) / CGFloat(tabs.count - 1)
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

    private func scrollToTabIfNeeded(_ tab: BrowserTab,
                                     containerGeometry: GeometryProxy,
                                     scrollViewProxy: RetroCompatibleScrollViewProxy,
                                     animated: Bool = true) {
        let index = position(of: tab)
        let tabWidth = widthForTab(selected: isSelected(tab), containerGeometry: containerGeometry)
        let tabOriginX = CGFloat(index) * widthForTab(selected: false, containerGeometry: containerGeometry)
        let point = CGPoint(x: tabOriginX + tabWidth, y: 0)
        let outOfBoundsWidth = point.x - (containerGeometry.size.width + scrollOffset)
        guard outOfBoundsWidth > 0 else { return }
        if animated {
            withAnimation {
                scrollViewProxy.scrollTo(point)
            }
        } else {
            scrollViewProxy.scrollTo(point)
        }
    }

}

struct BrowserTabBar_Preview: PreviewProvider {
    static var state = BeamState()

    static func tab(_ title: String) -> BrowserTab {
        let t = BrowserTab(state: state, browsingTreeOrigin: nil, note: BeamNote(title: "note"))
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
