//
//  BrowserTabBar.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowerTabBar: View {
    @Binding var tabs: [BrowserTab]
    @Binding var currentTab: UUID
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tabs, id: \.id) { tab in
                    BrowserTabView(tab: tab, selected: isSelected(tab))
                }
            }
        }
    }
    
    func isSelected(_ tab: BrowserTab) -> Bool {
        return tab.id == currentTab
    }
}


struct BrowserTabBar_Previews: PreviewProvider {
    @State static var tabs: [BrowserTab] = [BrowserTab(id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!, title: "test1"), BrowserTab(title: "test2"), BrowserTab(title: "test3")]
    @State static var currentTab = UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!
    static var previews: some View {
        BrowerTabBar(tabs: Self.$tabs, currentTab: Self.$currentTab)
    }
}
