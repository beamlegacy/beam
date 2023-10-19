//
//  AdvancedPreferencesGeneral.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI

struct AdvancedPreferencesGeneral: View {
    @State private var bundleIdentifier: String = Configuration.bundleIdentifier
    @State private var env: String = Configuration.env.rawValue
    @State private var useSidebar = PreferencesManager.useSidebar
    @State private var stateRestorationEnabled = Configuration.stateRestorationEnabled
    @State private var loggedIn: Bool = AuthenticationManager.shared.isAuthenticated    

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Bundle identifier:")
            } content: {
                Text(bundleIdentifier)
            }
            Settings.Row(hasDivider: true) {
                Text("Environment:")
            } content: {
                Text(env)
            }
            Settings.Row(hasDivider: true) {
                Text("Actions")
            } content: {
                CopyAccessToken
                ResetOnboarding
            }
            Settings.Row {
                Text("Use sidebar")
            } content: {
                useSidebarView
            }
            Settings.Row {
                Text("State Restoration Enabled")
            } content: {
                StateRestorationEnabledButton
            }
        }
    }

    private var CopyAccessToken: some View {
        Button(action: {
            if let accessToken = AuthenticationManager.shared.accessToken {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(accessToken, forType: .string)
            }
        }, label: {
            // TODO: loc
            Text("Copy Access Token").frame(minWidth: 100)
        }).disabled(!loggedIn)
    }

    private var ResetOnboarding: some View {
        Button(action: {
            Persistence.Authentication.hasSeenOnboarding = false
            AuthenticationManager.shared.username = nil
        }, label: {
            Text("Reset Onboarding").frame(minWidth: 100)
        })
    }

    private var useSidebarView: some View {
        return Toggle(isOn: $useSidebar) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: useSidebar) {
                PreferencesManager.useSidebar = $0
            }
    }

    private var StateRestorationEnabledButton: some View {
        Button(action: {
            Configuration.stateRestorationEnabled = !Configuration.stateRestorationEnabled
            stateRestorationEnabled = Configuration.stateRestorationEnabled
        }, label: {
            Text(String(describing: stateRestorationEnabled)).frame(minWidth: 100)
        })
    }
}

struct AdvancedPreferencesGeneral_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesGeneral()
    }
}
