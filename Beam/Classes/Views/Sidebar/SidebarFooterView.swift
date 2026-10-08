//
//  SidebarFooterView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 18/05/2022.
//

import SwiftUI
import BeamCore

struct SidebarFooterView: View {

    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            ButtonLabel(icon: "field-preferences") {
                openGeneralPreferences()
            }
        }
    }

    private func openGeneralPreferences() {
        (NSApp.delegate as? AppDelegate)?.openPreferencesWindow(to: .general)
    }
}

struct SidebarFooterView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarFooterView()
    }
}
