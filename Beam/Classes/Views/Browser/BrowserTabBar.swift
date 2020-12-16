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
                ForEach(tabs.indices, id: \.self) { index in
                    let tab = tabs[index]

                    HStack(spacing: 0) {
                        GeometryReader { reader in
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
                                            self.offset = CGSize(width: value.translation.width, height: 0)

                                            let tabFrame = reader.frame(in: .local)
                                            let movingLeft = value.location.x > 0 ? true : false
                                            currentIndex = tabs.firstIndex(of: currentTab!)!

                                            if movingLeft && tabFrame.midX > tabFrame.minX && currentTab != tabs.last {
                                                secondaryIndex = currentIndex + 1
                                            }

                                            if !movingLeft && tabFrame.midX < tabFrame.maxX && currentTab != tabs.first {
                                                secondaryIndex = currentIndex - 1
                                            }

                                            print(secondaryIndex)

                                        }
                                        .onEnded { _ in
                                            tabs.swapAt(currentIndex, secondaryIndex)
                                            self.offset = .zero
                                        }
                                )
                                .clipped()
                        }.frame(minWidth: isSelected(tab, at: index) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)

                        if tab.id != tabs.last!.id {
                            Rectangle()
                                .frame(width: 1, height: 26)
                                .foregroundColor(Color(.separatorColor))
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
}
