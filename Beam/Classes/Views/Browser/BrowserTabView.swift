//
//  BroserTabView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI

struct BrowserTabView: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    @State var showButton = false
    var selected: Bool

    static var tabFrameColor = Color(.tabFrame)

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Rectangle()
                .frame(width: 1, height: 28, alignment: .leading)
                .foregroundColor(Color(.separatorColor))
            Image("browser-tab-close")
            .resizable()
            .frame(width: 12, height: 12, alignment: .leading)
            .opacity(showButton ? 1 : 0)
                .foregroundColor(Color(.toolbarButtonIconColor))
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading, 8)
            .onTapGesture(count: 1) {
                closeTab(id: tab.id)
            }

            // fav icon:
            HStack(spacing: 8) {
                Spacer()

                if let icon = tab.favIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 16, maxHeight: 16, alignment: .center)
                }

                Text(tab.title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(.omniboxTextColor).opacity(selected ? 1.0 : 0.8))
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .lineLimit(1)

                Spacer(minLength: 16)
            }.frame(maxWidth: .infinity, alignment: .center)

            Rectangle()
                .frame(width: 1, height: 28, alignment: .trailing)
                .foregroundColor( selected ? Color.clear : Color(.separatorColor))
        }
        .frame(height: 26)
        .contentShape(Rectangle())
        .onHover(perform: { v in
            showButton = v
        })
        .accessibility(identifier: "browserTabBarView")
        .background(Rectangle().fill(selected ? Color(.tabBarBg) : Color(.tabFrame) ))
    }

    func closeTab(id: UUID) {
        for (i, t) in state.tabs.enumerated() where t.id == id {
            if i > 0 {
                state.currentTab = state.tabs[i - 1]
            } else if state.tabs.count > 1 {
                state.currentTab = state.tabs[i + 1]
            } else {
                state.currentTab = nil
                if let note = state.currentNote {
                    state.navigateToNote(note)
                } else {
                    state.navigateToJournal()
                }
            }
            _ = state.removeTab(i)
        }

    }
}

struct BrowserTabView_Previews: PreviewProvider {
    static var state = BeamState()
    static var tab = BrowserTab(state: state, originalQuery: "test tab1", note: BeamNote(title: "test"))
    static var previews: some View {
        Group {
            HStack {
                BrowserTabView(tab: tab, selected: false)
                BrowserTabView(tab: tab, selected: true)
                BrowserTabView(tab: tab, selected: false)
            }
        }
    }
}
