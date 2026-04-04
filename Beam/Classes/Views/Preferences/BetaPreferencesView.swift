//
//  BetaPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/01/2022.
//

import Foundation
import SwiftUI
import BeamCore

struct BetaPreferencesView: View, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    @State private var selectedDatabase = BeamData.shared.currentDatabase
    var databases: [BeamDatabase] {
        AppData.shared.currentAccount?.allDatabases ?? []
    }

    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Database:")
            } content: {
                databaseContent
            }
            Settings.Row(hasDivider: true) {
                Text("Debug UI:")
            } content: {
                DebugSectionCheckbox
                OmniboxScoreSectionCheckbox
            }
            Settings.Row {
                Text("Notes:")
            } content: {
                ReindexNotesContents
                RebuildNotesContents
                ValidateNotesContents
            }
        }
    }

    private var databaseContent: some View {
        VStack(alignment: .leading) {
            DatabasePicker
            Button(action: {
                DispatchQueue.global(qos: .userInteractive).async {
                    do {
                        try AppData.shared.currentAccount?.deleteEmptyDatabases()
                        AppDelegate.showMessage("Empty databases deleted")
                    } catch {
                        DispatchQueue.main.async {
                            AppDelegate.showError(error)
                        }
                    }
                }
            }, label: {
                Text("Delete empty databases")
                    .frame(maxWidth: 180)
            })
        }
    }

    private var DatabasePicker: some View {
        Picker("", selection: $selectedDatabase.onChange(dbChange)) {
            ForEach(databases, id: \.id) {
                Text($0.title).tag($0 as BeamDatabase?)
            }
        }.labelsHidden()
            .frame(maxWidth: 200)
    }

    private func dbChange(_ database: BeamDatabase?) {
        guard let database = database else { return }
        try? BeamData.shared.setCurrentDatabase(database)
    }

    private var DebugSectionCheckbox: some View {
        return Toggle(isOn: $showDebugSection) {
            Text("Show Debug Section")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showDebugSection, perform: {
                PreferencesManager.showDebugSection = $0
            })
    }

    private var OmniboxScoreSectionCheckbox: some View {
        return Toggle(isOn: $showOmniboxScoreSection) {
            Text("Show frecency / score in Omnibox")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showOmniboxScoreSection, perform: {
                PreferencesManager.showOmniboxScoreSection = $0
            })
    }

    private var ReindexNotesContents: some View {
        Button(action: { BeamNote.indexAllNotes(interactive: true) }, label: {
            Text("Reindex all notes content")
                .frame(width: 180)

        })
    }

    private var RebuildNotesContents: some View {
        Button(action: { try? BeamNote.rebuildAllNotes(self, interactive: true) }, label: {
            Text("Rebuild all notes content")
                .frame(width: 180)
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { try? BeamNote.validateAllNotes(interactive: true) }, label: {
            Text("Validate all notes content")
                .frame(width: 180)
        })
    }
}

struct BetaPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BetaPreferencesView()
    }
}
