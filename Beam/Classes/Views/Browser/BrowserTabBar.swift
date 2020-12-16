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

    @State private var dragState: (tab: BrowserTab, translation: CGSize, location: CGPoint)?
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
                            GeometryReader { reader in
                                BrowserTabView(tab: tab, selected: isSelected(tab))
                                    .contentShape(Rectangle())
                                    .offset(dragOffset(for: tab))
                                    .onTapGesture {
                                        currentTab = tab
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if !isSelected(tab) { currentTab = tab }
                                                self.dragState = (tab: tab, translation: value.translation, location: value.location)

                                                let tabFrame = reader.frame(in: .local)
                                                let movingLeft = value.location.x > 0 ? true : false
                                                currentIndex = tabs.firstIndex(of: currentTab!)!

                                                if movingLeft && tabFrame.midX > tabFrame.minX && currentTab != tabs.last {
                                                    secondaryIndex = currentIndex + 1
                                                }

                                                if !movingLeft && tabFrame.midX < tabFrame.maxX && currentTab != tabs.first {
                                                    secondaryIndex = currentIndex - 1
                                                }
                                            }
                                            .onEnded { _ in
                                                tabs.swapAt(currentIndex, secondaryIndex)
                                                dragState = nil
                                            }
                                    )
                                    .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }.zIndex(currentTab === tab ? 1 : 0)
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
        guard let state = self.dragState, state.tab === tab else { return .zero }
        return CGSize(width: state.translation.width, height: 0)
    }
}
