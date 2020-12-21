//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowserTabBar: View {

    enum Direction: String {
        case left, right, none
    }

    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?

    @State private var direction: Direction = .none
    @State private var offset = CGSize.zero

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
                                    .offset(x: currentTab == tab ? offset.width : .zero, y: 0)
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
                                                let delta = abs(value.startLocation.x - value.location.x)

                                                self.offset = value.translation

                                                print("tabMidX: \(tabMidX)")

                                                if direction == .right && delta > tabMidX && tab != tabs.last {
                                                    print("right swap")
                                                    tabs.remove(at: currentTabIndex)
                                                    tabs.insert(tab, at: currentTabIndex.advanced(by: 1))
                                                }

                                                if direction == .left && tabMidX < delta && tab != tabs.first {
                                                    print("left swap")
                                                    tabs.remove(at: currentTabIndex)
                                                    tabs.insert(tab, at: currentTabIndex.advanced(by: -1))
                                                }
                                            }
                                            .onEnded { _ in
                                                self.offset = .zero
                                            }
                                    )
                                    .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .zIndex(currentTab === tab ? 1 : 0)
                    }
                }
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor))
            }
        }.animation(.none)
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
}
