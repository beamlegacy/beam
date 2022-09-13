//
//  ClusteringPreferencesView.swift
//  Beam
//
//  Created by Remi Santos on 08/09/2022.
//

import SwiftUI
import Clustering

struct ClusteringPreferencesView: View {
    @State private var v2Enabled: Bool = PreferencesManager.enableClusteringV2
    @State private var showV1SettingsMenu = PreferencesManager.showClusteringSettingsMenu
    @State private var v2Threshold: Float = PreferencesManager.clusteringV2Threshold ?? -1


    private var isClusteringV2Supported: Bool {
        ClusteringType.smart.isSupported
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Settings.Container(contentWidth: PreferencesManager.contentWidth) {

                if isClusteringV2Supported {
                    Settings.Row(hasDivider: true) {
                        Text("Clustering V2")
                    } content: {
                        clusteringSelector
                        clusteringV2Threshold
                    }
                }

                Settings.Row {
                    Text("Clustering V1")
                } content: {
                    EnableClusteringSettingsCheckbox
                }

            }
        }
    }

    private var clusteringSelector: some View {
        return VStack(alignment: .leading) {
            Toggle(isOn: $v2Enabled) {
                Text("Enable")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: v2Enabled) {
                    PreferencesManager.enableClusteringV2 = $0
                }
            Settings.SubtitleLabel("Requires restart")
        }
    }

    private var thresholdFormatter: NumberFormatter {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 4
        return fmt
    }

    private var clusteringV2Threshold: some View {
        return VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Threshold")
                }
                TextField("", value: $v2Threshold, formatter: thresholdFormatter) { _ in
                } onCommit: {
                    if v2Threshold < 0 || v2Threshold > 1 {
                        PreferencesManager.clusteringV2Threshold = nil
                        fetchExistingClusteringV2Threshold()
                    } else {
                        PreferencesManager.clusteringV2Threshold = v2Threshold
                    }
                }.disableAutocorrection(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 65, height: 25, alignment: .center)
            }
            .onAppear {
                if PreferencesManager.clusteringV2Threshold == nil {
                    fetchExistingClusteringV2Threshold()
                }
            }
            Settings.SubtitleLabel("Requires restart")
        }
    }

    private func fetchExistingClusteringV2Threshold() {
        let defaultClustering = SmartClustering()
        v2Threshold = defaultClustering.getThreshold()
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
