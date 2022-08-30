//
//  BetaPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/01/2022.
//

import Foundation
import SwiftUI
import BeamCore
import Combine

class BetaPreferencesViewModel: ObservableObject {
    @Published var isSynchronizationRunning = AppData.shared.currentAccount!.isSynchronizationRunning
    @Published var isloggedIn = AuthenticationManager.shared.isLoggedIn
    @Published var synchronizationStatus: BeamObjectObjectSynchronizationStatus = .notStarted

    private var scope = Set<AnyCancellable>()

    init(objectManager: BeamObjectManager) {
        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.isloggedIn = AuthenticationManager.shared.isLoggedIn
        }.store(in: &scope)

        AppData.shared.currentAccount!.isSynchronizationRunningPublisher.receive(on: DispatchQueue.main).sink { [weak self] isSynchronizationRunning in
            self?.isSynchronizationRunning = isSynchronizationRunning
        }.store(in: &scope)

        objectManager.synchronizationStatusSubject.receive(on: DispatchQueue.main).sink { [weak self] synchronizationStatus in
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
        AppData.shared.currentAccount?.allDatabases ?? []
    }

    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @ObservedObject var viewModel: BetaPreferencesViewModel

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Synchronize:")
            } content: {
                synchronizationContent
            }
            Settings.Row(hasDivider: true) {
                Text("Status:")
            } content: {
                Text(viewModel.synchronizationStatus.description)
            }
            Settings.Row(hasDivider: true) {
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

    private var synchronizationContent: some View {
        VStack(alignment: .leading) {
            Button(action: {
                self.loading = true
                Persistence.Sync.BeamObjects.last_received_at = nil
                Persistence.Sync.BeamObjects.last_updated_at = nil
                Task { @MainActor in
                    do {
                        try BeamObjectChecksum.deleteAll();
                        _ = try AppDelegate.main.syncDataWithBeamObject(force: true)
                    } catch {
                        Logger.shared.logError("Error while syncing data: \(error)", category: .document)
                    }
                    self.loading = false
                }
            }, label: {
                Text("Force full synchronization")
                    .frame(maxWidth: 180)
            })
            .disabled(loading)

            Button(action: {
                AppData.shared.currentAccount?.stopSynchronization()
            }, label: {
                Text("Stop synchronization")
                    .frame(maxWidth: 180)
            })
            .disabled(!viewModel.isloggedIn || !viewModel.isSynchronizationRunning)
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
        BetaPreferencesView(viewModel: BetaPreferencesViewModel(objectManager: BeamObjectManager()))
    }
}
