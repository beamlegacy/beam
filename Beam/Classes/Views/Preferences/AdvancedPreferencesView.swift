import SwiftUI
import Preferences
import Sentry
import Combine
import BeamCore

var AdvancedPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .advanced, title: "Advanced", imageName: "preferences-developer") {
    AdvancedPreferencesView()
        .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
}

struct AdvancedPreferencesView: View {
    @State private var apiHostname: String = Configuration.apiHostname
    @State private var publicHostname: String = Configuration.publicHostname
    @State private var bundleIdentifier: String = Configuration.bundleIdentifier
    @State private var env: String = Configuration.env
    @State private var autoUpdate: Bool = Configuration.autoUpdate
    @State private var updateFeedURL = Configuration.updateFeedURL
    @State private var sentryEnabled = Configuration.sentryEnabled
    @State private var loggedIn: Bool = AccountManager().loggedIn
    @State private var networkEnabled: Bool = Configuration.networkEnabled
    @State private var encryptionEnabled = Configuration.encryptionEnabled
    @State private var privateKey = EncryptionManager.shared.privateKey().asString()
    @State private var stateRestorationEnabled = Configuration.stateRestorationEnabled

    // Database
    @State private var newDatabaseTitle = ""
    @State private var selectedDatabase = Database.defaultDatabase()
    private let databaseManager = DatabaseManager()
    @FetchRequest(entity: Database.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Database.title, ascending: true)],
                  predicate: NSPredicate(format: "deleted_at == nil"))
    var databases: FetchedResults<Database>

    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        let apiHostnameBinding = Binding<String>(get: {
            self.apiHostname
        }, set: {
            let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            self.apiHostname = cleanValue
            Configuration.apiHostname = cleanValue
        })

        let privateKeyBinding = Binding<String>(get: {
            privateKey
        }, set: {
            try? EncryptionManager.shared.replacePrivateKey($0)
        })

        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("Bundle identifier:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                Text(bundleIdentifier)
            }
            Preferences.Section {
                Text("API endpoint:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                TextField("api hostname", text: apiHostnameBinding)
                    .lineLimit(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
            }
            Preferences.Section {
                Text("Public endpoint:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                Text(publicHostname)
            }
            Preferences.Section {
                Text("Environment:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                Text(env)
            }
            Preferences.Section(bottomDivider: true) {
                Text("CoreData:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                Text(CoreDataManager.shared.storeURL?.absoluteString ?? "-").fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
                    .frame(maxWidth: 387)
            }

            Preferences.Section(title: "Automatic Update:") {
                Text(String(describing: autoUpdate))
            }
            Preferences.Section(title: "Software update URL:") {
                Text(String(describing: updateFeedURL)).fixedSize(horizontal: false, vertical: true)
            }
            Preferences.Section(title: "Sentry enabled:") {
                Text(String(describing: sentryEnabled)).fixedSize(horizontal: false, vertical: true)
            }
            Preferences.Section(title: "Sentry dsn:") {
                Text(Configuration.sentryDsn).fixedSize(horizontal: false, vertical: true)
            }
            Preferences.Section(title: "Network Enabled") {
                NetworkEnabledButton
            }
            Preferences.Section {
                Text("Browsing Session collection")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                BrowsingSessionCollectionCheckbox
            }

            Preferences.Section {
                Text("Enable TabGrouping Window menu")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                EnableTabGroupingWindowCheckbox
            }

            Preferences.Section {
                Text("Data backup")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                AutomaticBackupBeforeUpdate
            }

            Preferences.Section(title: "Encryption Enabled") {
                EncryptionEnabledButton
            }
            Preferences.Section(title: "Encryption key") {
                TextField("Private Key", text: privateKeyBinding)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
            }
            Preferences.Section(title: "Actions") {
                ResetAPIEndpointsButton
                CrashButton
                CopyAccessToken
                ResetPrivateKey
            }
            Preferences.Section(title: "State Restoration Enabled") {
                StateRestorationEnabledButton
            }
            Preferences.Section(title: "Database") {
                DatabasePicker
                Button(action: {
                    showNewDatabase = true
                }, label: {
                    Text("New Database").frame(minWidth: 100)
                })
                .popover(isPresented: $showNewDatabase) {
                    HStack {
                        TextField("title", text: $newDatabaseTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle()).frame(minWidth: 100, maxWidth: 400)
                            .padding()

                        Button(action: {
                            if !newDatabaseTitle.isEmpty {
                                let database = DatabaseStruct(title: newDatabaseTitle)
                                databaseManager.save(database, completion: { result in
                                    if case .success(let done) = result, done {

                                        if let database = try? Database.fetchWithId(CoreDataManager.shared.mainContext, database.id) {
                                            DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
                                            selectedDatabase = database
                                            try? CoreDataManager.shared.save()
                                        }
                                    }
                                    showNewDatabase = false
                                })
                            } else {
                                showNewDatabase = false
                            }
                            newDatabaseTitle = ""
                        }, label: {
                            Text("Create")
                        }).padding()
                    }
                }
            }
            Preferences.Section(title: "Passwords") {
                PasswordCSVImporter
                PasswordsDBDrop
            }
            Preferences.Section(title: "Reindex notes contents") {
                ReindexNotesContents
            }
            Preferences.Section(title: "Create 100 random notes") {
                Create100RandomNotes
            }
        }.onAppear {
            observeDefaultDatabase()
        }
    }

    @State private var showNewDatabase = false

    private var NetworkEnabledButton: some View {
        Button(action: {
            Configuration.networkEnabled = !Configuration.networkEnabled
            networkEnabled = Configuration.networkEnabled
        }, label: {
            Text(String(describing: networkEnabled)).frame(minWidth: 100)
        })
    }

    private var BrowsingSessionCollectionCheckbox: some View {
        Checkbox(checkState: PreferencesManager.browsingSessionCollectionIsOn, text: "Enable Browsing Session collection", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.browsingSessionCollectionIsOn = activated
        }
    }

    private var EnableTabGroupingWindowCheckbox: some View {
        Checkbox(checkState: PreferencesManager.showTabGrougpingMenuItem, text: "Enable TabGrouping Window menu", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.showTabGrougpingMenuItem = activated
        }
    }

    private var AutomaticBackupBeforeUpdate: some View {
        Checkbox(checkState: PreferencesManager.isDataBackupOnUpdateOn, text: "Backup data before update", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.isDataBackupOnUpdateOn = activated
        }
    }

    private var EncryptionEnabledButton: some View {
        Button(action: {
            Configuration.encryptionEnabled = !Configuration.encryptionEnabled
            encryptionEnabled = Configuration.encryptionEnabled
        }, label: {
            Text(String(describing: encryptionEnabled)).frame(minWidth: 100)
        })
    }

    private var ResetAPIEndpointsButton: some View {
        Button(action: {
            Configuration.reset()
            apiHostname = Configuration.apiHostname
        }, label: {
            // TODO: loc
            Text("Reset API Endpoints").frame(minWidth: 100)
        })
    }

    private var CrashButton: some View {
        Button(action: {
            SentrySDK.crash()
        }, label: {
            // TODO: loc
            Text("Force a crash").frame(minWidth: 100)
        })
    }

    private var CopyAccessToken: some View {
        Button(action: {
            if let accessToken = AuthenticationManager.shared.accessToken {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(accessToken, forType: .string)
            }
        }, label: {
            // TODO: loc
            Text("Copy Access Token").frame(minWidth: 100)
        }).disabled(!loggedIn)
    }

    private var ResetPrivateKey: some View {
        Button(action: {
            EncryptionManager.shared.resetPrivateKey()
            privateKey = EncryptionManager.shared.privateKey().asString()
        }, label: {
            // TODO: loc
            Text("Reset Private Key").frame(minWidth: 100)
        }).disabled(!Configuration.encryptionEnabled)
    }

    private var StateRestorationEnabledButton: some View {
        Button(action: {
            Configuration.stateRestorationEnabled = !Configuration.stateRestorationEnabled
            stateRestorationEnabled = Configuration.stateRestorationEnabled
        }, label: {
            Text(String(describing: stateRestorationEnabled)).frame(minWidth: 100)
        })
    }

    private var DatabasePicker: some View {
        return Picker("", selection: $selectedDatabase.onChange(dbChange), content: {
            ForEach(databases, id: \.id) {
                Text($0.title).tag($0)
            }
        }).frame(idealWidth: 100, maxWidth: 400)
    }

    private func dbChange(_ database: Database) {
        DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
    }

    @State private var cancellables = [AnyCancellable]()

    private func observeDefaultDatabase() {
        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { _ in
                selectedDatabase = Database.defaultDatabase()
            }
            .store(in: &cancellables)
    }

    private var PasswordCSVImporter: some View {
        Button(action: {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.canDownloadUbiquitousContents = false
            openPanel.allowsMultipleSelection = false
            openPanel.allowedFileTypes = ["csv", "txt"]
            openPanel.title = "Select a csv file exported from Chrome, Firefox or Safari"
            openPanel.begin { result in
                guard result == .OK, let url = openPanel.url else {
                    openPanel.close()
                    return
                }
                do {
                    let passwordStore = AppDelegate.main.data.passwordsDB
                    try PasswordImporter.importPasswords(fromCSV: url, into: passwordStore)
                } catch {
                    Logger.shared.logError(String(describing: error), category: .general)
                }
            }
        }, label: {
            Text("Import Passwords CSV File")
        })
    }

    private var PasswordsDBDrop: some View {
        Button(action: {
            let passwordManager = PasswordsManager()
            passwordManager.passwordsDB.deleteAll()
        }, label: {
            Text("Erase Passwords Database")
        })
    }

    private var ReindexNotesContents: some View {
        Button(action: { BeamNote.indexAllNotes() }, label: {
            Text("Reindex all notes' contents")
        })
    }

    private var Create100RandomNotes: some View {
        Button(action: {
            let documentManager = DocumentManager()
            let generator = FakeNoteGenerator(count: 100, journalRatio: 0.2, futureRatio: 0.05)
            generator.generateNotes()
            for note in generator.notes {
                note.save(documentManager: documentManager)
            }
        }, label: {
            Text("Create 100 Random notes")
        })
    }

}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
