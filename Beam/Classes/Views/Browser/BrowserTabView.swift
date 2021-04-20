//
//  BroserTabView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct BrowserTabView: View {
    @EnvironmentObject var state: BeamState
    @ObservedObject var tab: BrowserTab
    @State private var isHovering = false
    let isSelected: Bool

    private var foregroundColor: Color {
        isSelected ? BeamColor.Generic.text.swiftUI : BeamColor.Corduroy.swiftUI
    }

    private var backgroundColor: Color {
        guard !isSelected else { return BeamColor.Generic.background.swiftUI }
        return isHovering ? BeamColor.Mercury.swiftUI : BeamColor.Nero.swiftUI
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 32)
            HStack(spacing: BeamSpacing._40) {
                if let icon = tab.favIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                } else {
                    Icon(name: "field-web", size: 16, color: foregroundColor)
                }

                Text(tab.title)
                    .font(BeamFont.medium(size: 11).swiftUI)
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)
            }.frame(maxWidth: .infinity)
            .animation(nil)
            HStack {
                Spacer(minLength: 0)
                if isHovering {
                    ButtonLabel(icon: "tabs-close_xs", customStyle: ButtonLabelStyle.tinyIconStyle) {
                        closeTab(id: tab.id)
                    }
                    .padding(.horizontal, BeamSpacing._60)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3))
            .frame(width: 32)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .accessibility(identifier: "browserTabBarView")
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
    static var tab: BrowserTab = {
        let t = BrowserTab(state: state, originalQuery: "", note: BeamNote(title: "test"))
        t.title = "Tab Title"
        return t
    }()
    static var longTab: BrowserTab = {
        let t = BrowserTab(state: state, originalQuery: "", note: BeamNote(title: "test2"))
        t.title = "Very Very Very Very Very Very Very Very Very Long Tab"
        return t
    }()
    static var previews: some View {
            VStack {
                BrowserTabView(tab: tab, isSelected: false)
                    .frame(height: 28)
                BrowserTabView(tab: tab, isSelected: true)
                    .frame(height: 28)
                BrowserTabView(tab: longTab, isSelected: false)
                    .frame(height: 28)
            }.padding()
            .frame(width: 360)
    }
}
