//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

private struct Background: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color("TabBarBg"))
            GeometryReader { geometry in
                Path { path in
//                    path.move(to: CGPoint(x: 0, y: h))
//                    path.addLine(to: CGPoint(x: Int(geometry.size.width), y: h))
                    let h = Int(geometry.size.height - 1 )
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: Int(geometry.size.width), y: h))
                }
                .stroke(Color(NSColor.separatorColor))
            }
        }
    }
}

struct BrowserTabBar: View {
    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab?
    let minTabWidth = CGFloat(0)
    let maxTabWidth = CGFloat(150)
    var body: some View {
        ZStack {
            Background()
            HStack {
                ForEach(tabs, id: \.id) { tab in
                    BrowserTabView(tab: tab, selected: isSelected(tab))
                        .onTapGesture {
                            currentTab = tab
                        }
                        .frame(minWidth: isSelected(tab) ? 100 : minTabWidth, maxWidth: maxTabWidth, minHeight: 20, maxHeight: 20, alignment: .leading)
                }
            }
            .padding([.leading, .trailing], 2)
        }.frame(height: 28)
        .transition(.slide)
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
