//
//  AdvancedPreferencesMisc.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/07/2022.
//

import SwiftUI
import BeamCore

struct AdvancedPreferencesMisc: View {
    @State private var browsingSessionCollectionIsOn = PreferencesManager.browsingSessionCollectionIsOn
    @State private var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @State private var includeHistoryContentsInOmniBox = PreferencesManager.includeHistoryContentsInOmniBox
    @State private var enableOmnibeams = PreferencesManager.enableOmnibeams
    @State private var showClusteringSettingsMenu = PreferencesManager.showClusteringSettingsMenu

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row(hasDivider: true) {
                Text("Browsing Session collection")
            } content: {
                BrowsingSessionCollectionCheckbox
            }
            Settings.Row {
                Text("Show frecency / score in Omnibox")
            } content: {
                OmniboxScoreSectionCheckbox
            }
            Settings.Row {
                Text("Include history contents in Omnibox")
            } content: {
                HistoryInOmniboxCheckbox
            }
            Settings.Row(hasDivider: true) {
                Text("Omnibeams")
            } content: {
                OmnibeamsCheckbox
            }
            Settings.Row(hasDivider: true) {
                Text("Clustering Settings menu")
            } content: {
                EnableClusteringSettingsCheckbox
            }
            Settings.Row {
                Text("Collect Feedback:")
            } content: {
                CollectFeedbackSection()
            }
            Settings.Row(hasDivider: false) {
                Text("Export")
            } content: {
                ExportLogs
                ExportNotesSources
                ExportBrowsingSession
            }
        }
    }

    private var BrowsingSessionCollectionCheckbox: some View {
        return Toggle(isOn: $browsingSessionCollectionIsOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: browsingSessionCollectionIsOn) {
                PreferencesManager.browsingSessionCollectionIsOn = $0
            }
    }

    private var OmniboxScoreSectionCheckbox: some View {
        return Toggle(isOn: $showOmniboxScoreSection) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showOmniboxScoreSection) {
                PreferencesManager.showOmniboxScoreSection = $0
            }
    }

    private var HistoryInOmniboxCheckbox: some View {
        return Toggle(isOn: $includeHistoryContentsInOmniBox) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: includeHistoryContentsInOmniBox) {
                PreferencesManager.includeHistoryContentsInOmniBox = $0
            }
    }

    private var OmnibeamsCheckbox: some View {
        return Toggle(isOn: $enableOmnibeams) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: enableOmnibeams) {
                PreferencesManager.enableOmnibeams = $0
            }
    }

    private var EnableClusteringSettingsCheckbox: some View {
        return Toggle(isOn: $showClusteringSettingsMenu) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showClusteringSettingsMenu) {
                PreferencesManager.showClusteringSettingsMenu = $0
            }
    }

    private var ExportLogs: some View {
        Button(action: {
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = "Logs.txt"
            savePanel.begin { (result) in
                guard result == .OK, let url = savePanel.url else {
                    savePanel.close()
                    return
                }
                do {
                    let logs = Logger.shared.logFileString.split(separator: "\n")
                    let logsStr = logs.joined(separator: "\n")
                    try logsStr.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    Logger.shared.logError(String(describing: error), category: .general)
                }
            }
        }, label: {
            Text("Logs").frame(minWidth: 100)
        })
    }

    private var ExportNotesSources: some View {
        Button(action: {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.canChooseFiles = false
            openPanel.showsTagField = false
            openPanel.begin { (result) in
                guard result == .OK, let url = openPanel.url else {
                    openPanel.close()
                    return
                }
                export_all_note_sources(to: url)
                BeamData.shared.clusteringManager.addOrphanedUrlsFromCurrentSession(orphanedUrlManager: BeamData.shared.clusteringOrphanedUrlManager)
                BeamData.shared.clusteringOrphanedUrlManager.export(to: url)
                BeamData.shared.clusteringManager.exportSession(sessionExporter: BeamData.shared.sessionExporter, to: url, correctedPages: nil)
            }
        }, label: {
            Text("Note Sources").frame(minWidth: 100)
        })
    }

    private var ExportBrowsingSession: some View {
        Button(action: {

        }, label: {
            Text("Browsing Sessions").frame(minWidth: 100)
        })
    }
}

struct AdvancedPreferencesMisc_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesMisc()
    }
}

private struct CollectFeedbackSection: View {
    @State private var isCollectFeedbackEnabled = PreferencesManager.isCollectFeedbackEnabled
    @State private var showsCollectFeedbackAlert = PreferencesManager.showsCollectFeedbackAlert

    var body: some View {
        Toggle(isOn: $isCollectFeedbackEnabled) {
            Text("Send feedback of failed collect")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isCollectFeedbackEnabled) {
                PreferencesManager.isCollectFeedbackEnabled = $0
            }
        Toggle(isOn: $showsCollectFeedbackAlert) {
            Text("Show alert before sending collect feedback")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showsCollectFeedbackAlert) {
                PreferencesManager.showsCollectFeedbackAlert = $0
            }
    }
}
