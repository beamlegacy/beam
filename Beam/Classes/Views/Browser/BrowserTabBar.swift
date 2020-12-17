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
        let drag = DragGesture()
            .onChanged { self.offset = $0.translation }
            .onEnded {
                if $0.translation.width < -100 {
                    self.offset = .init(width: -1000, height: 0)
                } else if $0.translation.width > 100 {
                    self.offset = .init(width: 1000, height: 0)
                } else {
                    self.offset = .zero
                }
            }

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
                                                guard let currentTab = currentTab, let tabIndex = tabs.firstIndex(of: currentTab) else { return }
                                                let tabFrame = reader.frame(in: .global)
                                                let fullWidth = tabFrame.maxX
                                                let tabWidth = fullWidth / CGFloat(tabs.count)

                                                let delta = value.location.x - value.startLocation.x
                                                self.offset = value.translation

                                                print("tabWidth: \(tabWidth) / delta : \(delta) / offset: \(offset.width)")

                                                if delta >= tabWidth {
                                                    print("mid")
                                                    tabs.swapAt(tabIndex, tabIndex + 1)
                                                } else {
                                                    print("no mid")
                                                }
                                            }
                                            .onEnded { _ in
                                                // swapTabs()
                                                offset = .zero
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
        guard currentTab?.id == tab.id else { return .zero }
        return CGSize(width: offset.width, height: 0)
    }

    private func swapTabs() {
        if secondaryIndex < 0 || secondaryIndex >= tabs.count {
            offset = .zero
            return
        }
        tabs.swapAt(currentIndex, secondaryIndex)
        offset = .zero
    }
}
