//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

fileprivate struct Background: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color(hue: 0, saturation: 0, brightness: 0.97))
            GeometryReader { geometry in
                Path { path in
//                    path.move(to: CGPoint(x: 0, y: h))
//                    path.addLine(to: CGPoint(x: Int(geometry.size.width), y: h))
                    let h = Int(geometry.size.height - 1 )
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 3000, y: h))
                }
                .stroke(Color(hue: 0, saturation: 0, brightness: 0.4))
            }
        }
    }
}

struct BrowserTabBar: View {
    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: BrowserTab
    var body: some View {
        ZStack {
            Background()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tabs, id: \.id) { tab in
                        BrowserTabView(tab: tab, selected: isSelected(tab))
                            .onTapGesture {
                                currentTab = tab
                            }
                    }
                }.padding([.leading, .trailing], 5)
            }
        }.frame(height: 25)
    }
    
    func isSelected(_ tab: BrowserTab) -> Bool {
        return tab.id == currentTab.id
    }
}


struct BrowserTabBar_Previews: PreviewProvider {
    @State static var tabs: [BrowserTab] = [BrowserTab(originalQuery: "test1", id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!), BrowserTab(originalQuery: "test2"), BrowserTab(originalQuery: "test3")]
    @State static var currentTab = BrowserTab(originalQuery: "test1", id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!)
    static var previews: some View {
        BrowserTabBar(tabs: Self.$tabs, currentTab: Self.$currentTab)
    }
}
