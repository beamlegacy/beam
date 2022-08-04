//
//  AdvancedPreferencesAutoUpdate.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI

struct AdvancedPreferencesAutoUpdate: View {
    @State private var autoUpdate: Bool = Configuration.autoUpdate
    @State private var isDataBackupOnUpdateOn = PreferencesManager.isDataBackupOnUpdateOn
    @State private var updateFeedURL = Configuration.updateFeedURL

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Automatic Update")
            } content: {
                Text(String(describing: autoUpdate))
            }

            Settings.Row {
                Text("Software update URL")
            } content: {
                Text(String(describing: updateFeedURL))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
                    .frame(maxWidth: 387, alignment: .leading)
            }
            Settings.Row {
                Text("Data backup before update")
            } content: {
                AutomaticBackupBeforeUpdate
            }
        }
    }

    private var AutomaticBackupBeforeUpdate: some View {
        Toggle(isOn: $isDataBackupOnUpdateOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDataBackupOnUpdateOn) {
                PreferencesManager.isDataBackupOnUpdateOn = $0
            }
    }
}

struct AdvancedPreferencesAutoUpdate_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesAutoUpdate()
    }
}
