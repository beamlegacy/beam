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
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
            HStack(spacing: 0) {
                ZStack {
                    ForEach(tabs.indices, id: \.self) { index in
                        let tab = tabs[index]

                        HStack(spacing: 0) {
                            BrowserTabView(tab: tab, selected: isSelected(tab, at: index))
                                .contentShape(Rectangle())
                                .offset(x: currentTab === tab ? self.offset.width : 0, y: 0)
                                .onTapGesture {
                                    currentTab = tab
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isSelected(tab, at: index) { currentTab = tab }
                                            if currentTab == tab { currentIndex = index }
                                            self.offset = CGSize(width: value.translation.width, height: 0)

                                            if offset.width > 0 {
                                                print("right")
                                            }

                                            if offset.width < 0 {
                                                print("left")
                                            }
                                        }
                                        .onEnded { _ in
                                            // swapTabs(from: currentIndex, to: currentIndex + 1)
                                            self.offset = .zero
                                        }
                                )
                                .clipped()
                                .frame(minWidth: isSelected(tab, at: index) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)

                            if tab.id != tabs.last!.id {
                                Rectangle()
                                    .frame(width: 1, height: 26)
                                    .foregroundColor(Color(.separatorColor))
                            }
                        }
                    }
                }
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
        }
    }

    func isSelected(_ tab: BrowserTab, at index: Int) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }

    private func swapTabs(from fromIndex: Int, to toIndex: Int) {
        tabs.swapAt(fromIndex, toIndex)
    }
}
