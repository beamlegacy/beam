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
import Combine

let BetaPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .beta, title: "Beta", imageName: "preferences-developer") {
    BetaPreferencesView(viewModel: BetaPreferencesViewModel())
        .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
}

class BetaPreferencesViewModel: ObservableObject {
    @Published var isSynchronizationRunning = AppDelegate.main.isSynchronizationRunning
    @Published var isloggedIn = AuthenticationManager.shared.isLoggedIn
    @Published var synchronizationStatus: BeamObjectObjectSynchronizationStatus = .notStarted

    private var scope = Set<AnyCancellable>()

    init() {
        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] isAuthenticated in
            self?.isloggedIn = AuthenticationManager.shared.isLoggedIn
        }.store(in: &scope)

        AppDelegate.main.isSynchronizationRunningPublisher.receive(on: DispatchQueue.main).sink { [weak self] isSynchronizationRunning in
            self?.isSynchronizationRunning = isSynchronizationRunning
        }.store(in: &scope)

        BeamObjectManager.synchronizationStatusPublisher.receive(on: DispatchQueue.main).sink { [weak self] synchronizationStatus in
            self?.synchronizationStatus = synchronizationStatus
        }.store(in: &scope)
    }
}

struct BetaPreferencesView: View, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    private let contentWidth: Double = PreferencesManager.contentWidth

    @State private var loading: Bool = false

    @State private var selectedDatabase = BeamData.shared.currentDatabase
    var databases: [BeamDatabase] {
        BeamData.shared.currentAccount?.allDatabases ?? []
    }

    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @ObservedObject var viewModel: BetaPreferencesViewModel

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Synchronize:", bottomDivider: false, verticalAlignment: .top) {
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

                Button(action: {
                    AppDelegate.main.stopSynchronization()
                }, label: {
                    Text("Stop synchronization")
                        .frame(maxWidth: 180)
                })
                .disabled(!viewModel.isloggedIn || !viewModel.isSynchronizationRunning)
            }

            Preferences.Section(title: "Status:", bottomDivider: true, verticalAlignment: .top) {
                Text(viewModel.synchronizationStatus.description)
            }

            Preferences.Section(title: "Database:", bottomDivider: true) {
                VStack(alignment: .leading) {
                    DatabasePicker
                    Button(action: {
                        DispatchQueue.global(qos: .userInteractive).async {
                            do {
                                try BeamData.shared.currentAccount?.deleteEmptyDatabases()
                                DispatchQueue.main.async {
                                    AppDelegate.showMessage("Empty databases deleted")
                                }
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
        Button(action: { try? BeamNote.rebuildAllNotes(self) }, label: {
            Text("Rebuild all notes content")
                .frame(width: 180)
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { try? BeamNote.validateAllNotes() }, label: {
            Text("Validate all notes content")
                .frame(width: 180)
        })
    }
}

struct BetaPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        BetaPreferencesView(viewModel: BetaPreferencesViewModel())
    }
}
