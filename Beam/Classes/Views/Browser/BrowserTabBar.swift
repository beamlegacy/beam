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

    let minTabWidth = CGFloat(4)
    let maxTabWidth = CGFloat(150)

    var body: some View {
        GeometryReader { localReader in
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separatorColor))
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        ZStack {
                            HStack(spacing: 0) {
                                BrowserTabView(tab: tab, selected: isSelected(tab))
                                    .contentShape(Rectangle())
                                    .offset(dragOffset(for: tab))
                                    .onTapGesture {
                                        currentTab = tab
                                    }
                                    .animation(.none)
                                    .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .zIndex(currentTab == tab ? 1 : 0)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
//                        if !isSelected(tab) { currentTab = tab }
                        guard let currentTab = currentTab, let tabIndex = tabs.firstIndex(of: currentTab) else { return }
                        let tabFrame = localReader.frame(in: .global)
                        let fullFrame = tabFrame.width
                        let tabWidth = fullFrame / CGFloat(tabs.count)

                        // print("tabIndex: \(tabIndex)")
                        // print("tabFrame: \(tabFrame)")

                        let translation = value.location.x - value.startLocation.x
                        self.offset = CGSize(width: translation, height: 0)
                        currentIndex = tabIndex

                        let tabPosition = CGFloat(tabIndex) * tabFrame.width
                        let tabPositionOffset = tabPosition + translation
                        let newRatio = (tabPositionOffset) / fullFrame
                        let newPosition = CGFloat(tabs.count) * clamp(newRatio, 0, 1)
                        let secondaryIndex = Int(newPosition)

                        print("translation: \(translation) / tabIndex: \(tabIndex) / tabPosition: \(tabPosition) / tabPositionOffset: \(tabPositionOffset) / newPosition \(newPosition) / newIndex: \(secondaryIndex) / Twidth \(translation))")
                        // print("secondaryIndex", secondaryIndex)

                        if secondaryIndex != currentIndex {
                            if secondaryIndex < currentIndex {
                                tabs.remove(at: currentIndex)
                                tabs.insert(currentTab, at: secondaryIndex)
                            } else {
                                if secondaryIndex + 1 == tabs.count {
                                    tabs.append(currentTab)
                                } else {
                                    tabs.insert(currentTab, at: secondaryIndex)
                                }
                                tabs.remove(at: currentIndex)
                            }
                        }

                    }
                    .onEnded { _ in
                        offset = .zero
                        // swapTabs()
                    }
            )
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
}
