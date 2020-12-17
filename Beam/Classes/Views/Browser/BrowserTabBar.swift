//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowserTabBar: View {
    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?
    @GestureState var isDetectingLongPress = false

    @State private var offset = CGSize.zero
    @State private var currentIndex = -1
    @State private var secondaryIndex = -1

    let minTabWidth = CGFloat(4)
    let maxTabWidth = CGFloat(150)

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    ZStack {
                        HStack(spacing: 0) {
                            GeometryReader { localReader in
                                BrowserTabView(tab: tab, selected: isSelected(tab))
                                    .contentShape(Rectangle())
                                    .offset(dragOffset(for: tab))
                                    .onTapGesture {
                                        currentTab = tab
                                    }
                                    .animation(.none)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if !isSelected(tab) { currentTab = tab }
                                                guard let currentTab = currentTab, let tabIndex = tabs.firstIndex(of: currentTab) else { return }
                                                let tabFrame = localReader.frame(in: .global)
                                                let fullFrame = tabFrame.width * CGFloat(tabs.count)

                                                // print("tabIndex: \(tabIndex)")
                                                // print("tabFrame: \(tabFrame)")

                                                self.offset = value.translation
                                                currentIndex = tabIndex

                                                secondaryIndex = Int(floor(CGFloat(tabIndex + 1) * (tabFrame.maxX + value.location.x) / fullFrame))

                                                print("maxX + X", tabFrame.maxX + value.location.x, secondaryIndex)
                                                // print("secondaryIndex", secondaryIndex)

                                                if secondaryIndex != currentIndex {
                                                    if secondaryIndex < currentIndex {
                                                        tabs.remove(at: currentIndex)
                                                        tabs.insert(currentTab, at: secondaryIndex)
                                                    } else {
                                                        tabs.remove(at: currentIndex)
                                                        tabs.insert(currentTab, at: secondaryIndex - 1)
                                                    }
                                                }

                                            }
                                            .onEnded { _ in
                                                offset = .zero
                                                // swapTabs()
                                            }
                                    )
                                    .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }.zIndex(currentTab == tab ? 1 : 0)
                }
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
        }
    }

    private func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func dragOffset(for tab: BrowserTab) -> CGSize {
        guard let currentTab = currentTab, currentTab.id == tab.id else { return .zero }
        return CGSize(width: offset.width, height: 0)
    }

    private func swapTabs() {
        /*if secondaryIndex < 0 || secondaryIndex >= tabs.count {
            offset = .zero
            return
        }*/
        tabs.swapAt(currentIndex, secondaryIndex)
        offset = .zero
    }
}
