//
//  SidebarFooterView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 18/05/2022.
//

import SwiftUI
import BeamCore

struct SidebarFooterView: View {

    let username: String?

    @State private var showMenu: Bool = false
    @EnvironmentObject var state: BeamState

    var body: some View {
        HStack(spacing: 6) {
            if let username = username {
                HStack {
                    UsernameBadgeView(username: username)
                    Text(username)
                }
                .padding(.trailing, 12)
                .overlay(menu)
            } else {
                ButtonLabel(loc("Sign Up or Sign In"), icon: "editor-account_placeholder", customStyle: buttonLabelStyle) {
                    openAccountPreferences()
                }
            }
            Spacer()
            ButtonLabel(icon: "field-preferences") {
                openGeneralPreferences()
            }
        }

    }

    @ViewBuilder private var menu: some View {
            Menu("") {
                if let url = BeamNoteSharingUtils.getProfileLink() {
                    Button("Public Profile") {
                        state.showSidebar = false
                        state.createTab(withURLRequest: URLRequest(url: url))
                    }
                }
                Button("Account Settings") {
                    openAccountPreferences()
                }
            }.menuStyle(.borderlessButton)
    }

    private func openAccountPreferences() {
        (NSApp.delegate as? AppDelegate)?.openPreferencesWindow(to: .accounts)
    }

    private func openGeneralPreferences() {
        (NSApp.delegate as? AppDelegate)?.openPreferencesWindow(to: .general)
    }

    private var buttonLabelStyle: ButtonLabelStyle {
        ButtonLabelStyle(font: BeamFont.medium(size: 12).swiftUI, spacing: 6, foregroundColor: BeamColor.Niobium.swiftUI)
    }
}

struct SidebarFooterView_Previews: PreviewProvider {

    static let state = BeamState()

    static var previews: some View {
        Group {
            SidebarFooterView(username: "Ludovic")
            SidebarFooterView(username: nil)
        }.environmentObject(state)
    }
}
