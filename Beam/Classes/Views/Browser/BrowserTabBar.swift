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
    let minTabWidth = CGFloat(4)
    let maxTabWidth = CGFloat(150)
    @State private var offset = CGSize.zero
    @GestureState var isDetectingLongPress = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separatorColor))
            HStack(spacing: 0) {
                ForEach(tabs, id: \.id) { tab in
                    HStack(spacing: 0) {
                        BrowserTabView(tab: tab, selected: isSelected(tab))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentTab = tab
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        if !isSelected(tab) {
                                            currentTab = tab
                                        }
                                        self.offset = CGSize(width: gesture.translation.width, height: 0)
                                        print("Dragging \(self.offset)")
                                    }

                                    .onEnded { _ in
                    //                    if abs(self.offset.width) > 100 {
                    //                        // remove the card
                    //                    } else {
                                            self.offset = .zero
                    //                    }
                                        print("Dragging ended \(self.offset)")
                                    }
                            )
//                            .offset(isSelected(tab) ? offset : CGSize.zero)
                            .clipped()
                            .frame(minWidth: isSelected(tab) ? 150 : minTabWidth, maxWidth: .infinity, alignment: .leading)
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
        .transition(.identity)
        .animation(nil)
    }

    func isSelected(_ tab: BrowserTab) -> Bool {
        guard let ctab = currentTab else { return false }
        return tab.id == ctab.id
    }
}

//struct BrowserTabBar_Previews: PreviewProvider {
//    static var state = BeamState(data: BeamData())
//    @State static var tabs: [BrowserTab] = [BrowserTab(state: state, originalQuery: "test1", note: nil, id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!), BrowserTab(state: state, originalQuery: "test2", note: nil), BrowserTab(state: state, originalQuery: "test3", note: nil)]
//    @State static var currentTab = BrowserTab(state: state, originalQuery: "test1", note: nil, id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!)
//    static var previews: some View {
//        BrowserTabBar(tabs: Self.$tabs, currentTab: Self.$currentTab)
//    }
//}
