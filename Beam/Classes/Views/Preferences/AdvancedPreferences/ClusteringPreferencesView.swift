//
//  ClusteringPreferencesView.swift
//  Beam
//
//  Created by Remi Santos on 08/09/2022.
//

import SwiftUI
import Clustering

struct ClusteringPreferencesView: View {
    @State private var showV1SettingsMenu = PreferencesManager.showClusteringSettingsMenu

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Settings.Container(contentWidth: PreferencesManager.contentWidth) {
                Settings.Row {
                    Text("Clustering V1")
                } content: {
                    EnableClusteringSettingsCheckbox
                }

            }
        }
    }

    private var EnableClusteringSettingsCheckbox: some View {
        return Toggle(isOn: $showV1SettingsMenu) {
            Text("Show Clustering Candidates Settings")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showV1SettingsMenu) {
                PreferencesManager.showClusteringSettingsMenu = $0
            }
    }

}

struct ClusteringPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        ClusteringPreferencesView()
    }
}
