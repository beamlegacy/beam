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
                    GeometryReader { proxy in
                        ButtonLabel(username, variant: .dropdown) {
                            showMenuView(at: proxy)
                        }
                    }.frame(height: 20)
                }
                .padding(.trailing, 12)
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

    func showMenuView(at proxy: GeometryProxy) {

        guard let window = AppDelegate.main.window else { return }
        let origin = proxy.safeTopLeftGlobalFrame(in: window).origin
        let point = origin.flippedPointToTopLeftOrigin(in: window)

        let menu = ContextMenuFormatterView(key: "sidebarcontextmenu", items: contextMenuItems, defaultSelectedIndex: 0, canBecomeKey: true)
        CustomPopoverPresenter.shared.presentFormatterView(menu, atPoint: point)
    }

    private var contextMenuItems: [ContextMenuItem] {
        var menu = [ContextMenuItem(title: "Account Settings", action: openAccountPreferences)]
        if let url = BeamNoteSharingUtils.getProfileLink() {
            menu.append(ContextMenuItem(title: "Public Profile", action: { showPublicProfile(at: url) }))
        }
        return menu
    }

    private func showPublicProfile(at url: URL) {
        state.showSidebar = false
        state.createTab(withURLRequest: URLRequest(url: url))
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
