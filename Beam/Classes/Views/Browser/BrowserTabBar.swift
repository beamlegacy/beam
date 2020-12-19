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
                                                let tabFrame = reader.frame(in: .global)
                                                let tabWidth = tabFrame.width / CGFloat(tabs.count)
                                                let tabMidX = tabWidth / 2

                                                self.offset = value.translation
                                                print(tabWidth, tabMidX, position(of: tab))

                                                if value.translation.width > tabMidX {
                                                    if let index = tabs.firstIndex(of: tab) {
                                                        tab.isHidden = true
                                                        withAnimation {
                                                            tabs.remove(at: index)
                                                            tabs.insert(currentTab!, at: index + 1)
                                                        }

                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                self.offset = .zero
                                            }
                                    )
                                    .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
                            }
                        }.zIndex(currentTab === tab ? 1 : 0)
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

    private func moveToNext(_ tab: BrowserTab) {
        print(position(of: tab))
        // let nextTab = tabs.insert(currentTab!, at: 1)
        // print(nextTab)
    }

    private func moveToPrev(_ tab: BrowserTab) {

    }

    private func dragOffset(for tab: BrowserTab) -> CGSize {
        guard currentTab?.id == tab.id else { return .zero }
        return CGSize(width: offset.width, height: 0)
    }
}
