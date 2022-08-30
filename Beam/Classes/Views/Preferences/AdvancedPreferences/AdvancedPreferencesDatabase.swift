//
//  AdvancedPreferencesDatabase.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 28/07/2022.
//

import SwiftUI
import Combine

struct AdvancedPreferencesDatabase: View {
    @State private var cancellables = [AnyCancellable]()

    // Database
    @State private var newDatabaseTitle = ""
    @State private var selectedDatabase = BeamData.shared.currentDatabase
    var databases: [BeamDatabase] {
        AppData.shared.currentAccount?.allDatabases ?? []
    }

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("CoreData:")
            } content: {
                HStack {
                    Text(CoreDataManager.shared.storeURL?.absoluteString ?? "-")
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                        .frame(maxWidth: 387)
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(CoreDataManager.shared.storeURL?.absoluteString ?? "-", forType: .string)
                    },
                           label: { Text("copy") })
                }
            }
            Settings.Row {
                Text("Database")
            } content: {
                DatabasePicker
                Button(action: {
                    DispatchQueue.userInitiated.async {
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
        }.onAppear {
            startObservers()
        }
        .onDisappear {
            stopObservers()
        }
    }

    private var DatabasePicker: some View {
        Picker("", selection: $selectedDatabase.onChange(dbChange)) {
            ForEach(databases, id: \.id) {
                Text($0.title).tag($0 as BeamDatabase?)
            }
        }.labelsHidden()
        .frame(idealWidth: 100, maxWidth: 400)
    }

    private func dbChange(_ database: BeamDatabase?) {
        guard let database = database else { return }
        try? BeamData.shared.setCurrentDatabase(database)
    }

    private func startObservers() {
        BeamData.shared.currentDatabaseChanged
            .sink { _ in
                selectedDatabase = BeamData.shared.currentDatabase
            }
            .store(in: &cancellables)
        AppData.shared.currentAccount?.$allDatabases
            .sink { _ in
                selectedDatabase = BeamData.shared.currentDatabase
            }
            .store(in: &cancellables)
    }

    private func stopObservers() {
        cancellables.removeAll()
    }
}

struct AdvancedPreferencesDatabase_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesDatabase()
    }
}
