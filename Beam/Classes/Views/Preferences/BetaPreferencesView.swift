//
//  BetaPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/01/2022.
//

import Foundation
import SwiftUI
import Preferences
import BeamCore

let BetaPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .beta, title: "Beta", imageName: "preferences-developer") {
    BetaPreferencesView()
        .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
}

struct BetaPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    @State private var loading: Bool = false

    @State private var selectedDatabase = Database.defaultDatabase()
    private let databaseManager = DatabaseManager()
    @FetchRequest(entity: Database.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Database.title, ascending: true)],
                  predicate: NSPredicate(format: "deleted_at == nil"))
    var databases: FetchedResults<Database>

    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Synchronize:", bottomDivider: true, verticalAlignment: .top) {
                Button(action: {
                    self.loading = true
                    Persistence.Sync.BeamObjects.last_received_at = nil
                    Persistence.Sync.BeamObjects.last_updated_at = nil
                    AppDelegate.main.syncDataWithBeamObject(force: true) { _ in
                        self.loading = false
                    }
                }, label: {
                    Text("Force full synchronization")
                        .frame(maxWidth: 180)
                })
                .disabled(loading)
            }

            Preferences.Section(title: "Database:", bottomDivider: true) {
                VStack(alignment: .leading) {
                    DatabasePicker
                    Button(action: {
                        DispatchQueue.global(qos: .userInteractive).async {
                            let databaseManager = DatabaseManager()
                            databaseManager.deleteEmptyDatabases(onlyAutomaticCreated: false) { result in
                                switch result {
                                case .success: AppDelegate.showMessage("Empty databases deleted")
                                case .failure(let error): AppDelegate.showError(error)
                                }
                            }
                        }
                    }, label: {
                        Text("Delete empty databases")
                            .frame(maxWidth: 180)
                    })
                }
            }

            Preferences.Section(bottomDivider: true) {
                Text("Debug UI:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                DebugSectionCheckbox
                OmniboxScoreSectionCheckbox
            }

            Preferences.Section(title: "Notes:", verticalAlignment: .top) {
                ReindexNotesContents
                RebuildNotesContents
                ValidateNotesContents
            }
        }
    }

    private var DatabasePicker: some View {
        Picker("", selection: $selectedDatabase.onChange(dbChange)) {
            ForEach(databases, id: \.id) {
                Text($0.title).tag($0)
            }
        }.labelsHidden()
        .frame(maxWidth: 200)
    }

    private func dbChange(_ database: Database?) {
        guard let database = database else { return }
        DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
    }

    private var DebugSectionCheckbox: some View {
        return Toggle(isOn: $showDebugSection) {
            Text("Show Debug Section")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showDebugSection].publisher.first()) {
                PreferencesManager.showDebugSection = $0
            }
    }

    private var OmniboxScoreSectionCheckbox: some View {
        return Toggle(isOn: $showOmniboxScoreSection) {
            Text("Show frecency / score in Omnibox")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showOmniboxScoreSection].publisher.first()) {
                PreferencesManager.showOmniboxScoreSection = $0
            }
    }

    private var ReindexNotesContents: some View {
        Button(action: { BeamNote.indexAllNotes() }, label: {
            Text("Reindex all notes content")
                .frame(width: 180)

        })
    }

    private var RebuildNotesContents: some View {
        Button(action: { BeamNote.rebuildAllNotes() }, label: {
            Text("Rebuild all notes content")
                .frame(width: 180)
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { BeamNote.validateAllNotes() }, label: {
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
