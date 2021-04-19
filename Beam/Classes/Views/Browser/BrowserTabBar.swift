//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowserTabBar: View {
    @EnvironmentObject var state: BeamState

    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?

    @State private var direction: Direction = .none
    @State private var offset = CGSize.zero

    private enum Direction {
        case left, right, none
    }
    private let BOUNCE_BACK_VALUE = CGFloat(100)
    private let minTabWidth = CGFloat(4)
    private let maxTabWidth = CGFloat(150)

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        BrowserTabView(tab: tab, isSelected: isSelected(tab))
                            .offset(x: currentTab == tab ? self.offset.width : .zero, y: 0)
                            .onTapGesture {
                                currentTab = tab
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragGestureOnChange(for: tab, gestureValue: value, containerGeometry: geometry)
                                    }
                                    .onEnded { _ in
                                        self.offset = .zero
                                    }
                            )
                            .frame(minWidth: isSelected(tab) ? maxTabWidth : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            .zIndex(currentTab === tab ? 1 : 0)
                        Separator()
                            .padding(.vertical, 6)
                    }
                }
                .animation(nil)
            }
            ButtonLabel(icon: "tabs-new", customStyle: ButtonLabelStyle.tinyIconStyle) {
                state.startNewSearch()
            }
            .padding(.horizontal, BeamSpacing._100)
            .padding(.vertical, BeamSpacing._60)
        }
        .frame(height: 28)
        .background(
            BeamColor.Generic.background.swiftUI
                .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 0.5)
                .shadow(color: Color.black.opacity(0.04), radius: 7, x: 0, y: 2)
        )
        .animation(!state.windowIsResizing ? .easeInOut(duration: 0.3) : nil)
    }

    private func dragGestureOnChange(for tab: BrowserTab,
                                     gestureValue: DragGesture.Value,
                                     containerGeometry: GeometryProxy) {
        if !isSelected(tab) { currentTab = tab }
        let currentTabIndex = position(of: tab)
        let direction = detectDirection(from: gestureValue)

        let tabFrame = containerGeometry.frame(in: .global)
        let tabWidth = tabFrame.width / CGFloat(tabs.count)
        let tabMidX = tabWidth / 2
        let delta = abs(gestureValue.location.x - gestureValue.startLocation.x)

        var offset = gestureValue.translation

        if direction == .left && BOUNCE_BACK_VALUE < delta && tab == tabs.first ||
            direction == .right && delta > BOUNCE_BACK_VALUE && tab == tabs.last {
            offset = .zero
        } else if direction == .right && delta > tabMidX && tab != tabs.last {
            self.moveTabs(from: currentTabIndex, by: Int((delta - tabMidX) / tabWidth) + 1, with: tab)
        } else if direction == .left && tabMidX < delta && tab != tabs.first {
            self.moveTabs(from: currentTabIndex, by: Int((tabMidX - delta) / tabWidth) - 1, with: tab)
        }
        self.offset = offset
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func position(of tab: BrowserTab) -> Int {
        return tabs.firstIndex(of: tab) ?? 0
    }

    private func detectDirection(from value: DragGesture.Value) -> Direction {
        return value.startLocation.x > value.location.x ? .left : .right
    }

    private func moveTabs(from currentIndex: Int, by index: Int, with tab: BrowserTab) {
        tabs.remove(at: currentIndex)
        tabs.insert(tab, at: currentIndex.advanced(by: index).clamp(0, tabs.count))
    }
}
