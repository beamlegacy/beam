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

    enum Direction: String {
        case left, right, none
    }

    let BOUNCE_BACK_VALUE = CGFloat(100)

    let minTabWidth = CGFloat(4)
    let maxTabWidth = CGFloat(150)

    var body: some View {
        GeometryReader { reader in
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor))
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        ZStack {
                            HStack(spacing: 0) {
                                BrowserTabView(tab: tab, selected: isSelected(tab))
                                    .offset(x: currentTab == tab ? self.offset.width : .zero, y: 0)
                                    .animation(state.mode == Mode.web ? .easeInOut(duration: 0.32) : .none)
                                    .onTapGesture {
                                        currentTab = tab
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if !isSelected(tab) { currentTab = tab }
                                                let currentTabIndex = position(of: tab)
                                                let direction = detectDirection(from: value)

                                                let tabFrame = reader.frame(in: .global)
                                                let tabWidth = tabFrame.width / CGFloat(tabs.count)
                                                let tabMidX = tabWidth / 2
                                                let delta = abs(value.location.x - value.startLocation.x)

                                                self.offset = value.translation

                                                if direction == .left && BOUNCE_BACK_VALUE < delta && tab == tabs.first ||
                                                   direction == .right && delta > BOUNCE_BACK_VALUE && tab == tabs.last { self.offset = .zero }

                                                if direction == .right && delta > tabMidX && tab != tabs.last {
                                                    self.moveTabs(from: currentTabIndex, by: Int((delta - tabMidX) / tabWidth) + 1, with: tab)
                                                }

                                                if direction == .left && tabMidX < delta && tab != tabs.first {
                                                    self.moveTabs(from: currentTabIndex, by: Int((tabMidX - delta) / tabWidth) - 1, with: tab)
                                                }
                                            }
                                            .onEnded { _ in
                                                self.offset = .zero
                                            }
                                    )
                                    .frame(minWidth: isSelected(tab) ? maxTabWidth : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .zIndex(currentTab === tab ? 1 : 0)
                    }
                }
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor))
            }
            .animation(.none)
        }
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
        tab.isHidden = true
        tabs.remove(at: currentIndex)
        tabs.insert(tab, at: currentIndex.advanced(by: index).clamp(0, tabs.count))
    }
}
