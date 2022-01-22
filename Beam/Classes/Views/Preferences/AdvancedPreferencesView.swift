// swiftlint:disable file_length
import SwiftUI
import Preferences
import Sentry
import Combine
import BeamCore

var AdvancedPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .advanced, title: "Advanced", imageName: "preferences-developer") {
    AdvancedPreferencesView()
        .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
}

//swiftlint:disable:next function_body_length type_body_length
struct AdvancedPreferencesView: View {
    @State private var apiHostname: String = Configuration.apiHostname
    @State private var publicHostname: String = Configuration.publicHostname
    @State private var bundleIdentifier: String = Configuration.bundleIdentifier
    @State private var env: String = Configuration.env.rawValue
    @State private var autoUpdate: Bool = Configuration.autoUpdate
    @State private var updateFeedURL = Configuration.updateFeedURL
    @State private var sentryEnabled = Configuration.sentryEnabled
    @State private var loggedIn: Bool = AuthenticationManager.shared.isAuthenticated
    @State private var networkEnabled: Bool = Configuration.networkEnabled
    @State private var privateKey = EncryptionManager.shared.privateKey().asString()
    @State private var stateRestorationEnabled = Configuration.stateRestorationEnabled
    @State private var loading: Bool = false

    @State var showPNSView = PreferencesManager.showPNSView
    @State var pnsJSIsOn = PreferencesManager.PnsJSIsOn
    @State var browsingSessionCollectionIsOn = PreferencesManager.browsingSessionCollectionIsOn
    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @State var showTabGrougpingMenuItem = PreferencesManager.showTabGrougpingMenuItem
    @State var isDataBackupOnUpdateOn = PreferencesManager.isDataBackupOnUpdateOn

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

        ScrollView(.vertical, showsIndicators: false) {
            Preferences.Container(contentWidth: contentWidth) {
                Preferences.Section {
                    Text("Bundle identifier:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 250, alignment: .trailing)
                } content: {
                    Text(bundleIdentifier)
                }
                Preferences.Section(bottomDivider: true) {
                    Text("Environment:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    Text(env)
                }

                Preferences.Section {
                    Text("API endpoint:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    TextField("api hostname", text: apiHostnameBinding)
                        .lineLimit(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
                    ResetAPIEndpointsButton
                }
                Preferences.Section {
                    Text("Public endpoint")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    Text(publicHostname)
                }
                Preferences.Section(title: "Network Enabled") {
                    NetworkEnabledButton
                }
                Preferences.Section(title: "", bottomDivider: true) {
                    Button(action: {
                        self.loading = true
                        Persistence.Sync.BeamObjects.last_received_at = nil
                        Persistence.Sync.BeamObjects.last_updated_at = nil
                        AppDelegate.main.syncDataWithBeamObject(force: true) { _ in
                            self.loading = false
                        }
                    }, label: {
                        Text("Force full sync").frame(minWidth: 100)
                    })
                    .disabled(loading)
                }

                Preferences.Section(bottomDivider: true) {
                    Text("CoreData:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
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

                Preferences.Section(title: "Automatic Update") {
                    Text(String(describing: autoUpdate))
                }
                Preferences.Section(title: "Software update URL") {
                    Text(String(describing: updateFeedURL))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                        .frame(maxWidth: 387)
                }
                Preferences.Section(bottomDivider: true) {
                    Text("Data backup before update")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    AutomaticBackupBeforeUpdate
                }

                Preferences.Section(title: "Sentry enabled") {
                    Text(String(describing: sentryEnabled)).fixedSize(horizontal: false, vertical: true)
                }
                Preferences.Section(title: "Sentry dsn", bottomDivider: true) {
                    Text(Configuration.sentryDsn)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                        .frame(maxWidth: 387)
                }

                Preferences.Section(bottomDivider: true) {
                    Text("TabGrouping Window menu")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    EnableTabGroupingWindowCheckbox
                }
                Preferences.Section(title: "Database", bottomDivider: true) {
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
                                let beforeDb = DatabaseManager.defaultDatabase
                                if !newDatabaseTitle.isEmpty {
                                    let database = DatabaseStruct(title: newDatabaseTitle)
                                    databaseManager.save(database, completion: { result in
                                        if case .success(let done) = result, done {

                                            if let database = try? Database.fetchWithId(CoreDataManager.shared.mainContext, database.id) {
                                                DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
                                                selectedDatabase = database
                                                try? CoreDataManager.shared.save()
                                                DatabaseManager.showRestartAlert(beforeDb,
                                                                                 DatabaseManager.defaultDatabase)
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
                        Text("Delete empty databases").frame(minWidth: 100)
                    })
                }

                Preferences.Section(title: "Export ", bottomDivider: true) {
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
                            AppDelegate.main.data.clusteringOrphanedUrlManager.export(to: url)
                        }
                    }, label: {
                        Text("Note Sources").frame(minWidth: 100)
                    })

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
                            export_all_browsing_sessions(to: url)
                        }
                    }, label: {
                        Text("Browsing Sessions").frame(minWidth: 100)
                    })
                }

                Preferences.Section(title: "Cleanup ", bottomDivider: true) {
                    Button(action: {
                        let manager = DocumentManager()
                        manager
                            .allDocumentsIds(includeDeletedNotes: true)
                            .forEach {
                                let note = BeamNote.fetch(id: $0, includeDeleted: false, keepInMemory: false)
                                note?.save { _ in }
                            }
                    }, label: {
                        Text("Notes browsing sessions").frame(minWidth: 100)
                    })
                    Button(action: {
                        self.loading = true
                        BrowsingTreeStoreManager.shared.legacyCleanup { _ in
                            self.loading = false
                        }
                    }, label: {
                        Text("Legacy browsing trees").frame(minWidth: 100)
                    }).disabled(loading)
                }
                Preferences.Section(title: "Encryption key", bottomDivider: true) {
                    TextField("Private Key", text: privateKeyBinding)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
                    Text((try? privateKeyBinding.wrappedValue.SHA256()) ?? "-")
                    ResetPrivateKey
                    VerifyPrivateKey
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Browsing Session collection")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    BrowsingSessionCollectionCheckbox
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Show Debug Section")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    DebugSectionCheckbox
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Show frecency / score in Omnibox")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    OmniboxScoreSectionCheckbox
                }

                Preferences.Section(verticalAlignment: .top) {
                    Text("Collect Feedback:")
                } content: {
                    CollectFeedbackSection()
                }

                Preferences.Section(bottomDivider: false) {
                    Text("Enable Point and Shoot view")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    PnsViewEnabledCheckbox
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Enable Point and Shoot Javascript")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    PnsJSEnabledCheckbox
                }

                Preferences.Section(title: "Actions", bottomDivider: true) {
                    CrashButton
                    CopyAccessToken
                    ResetOnboarding
                }
                Preferences.Section(title: "State Restoration Enabled", bottomDivider: true) {
                    StateRestorationEnabledButton
                }

                Preferences.Section(title: "Passwords", bottomDivider: true) {
                    PasswordCSVImporter
                    PasswordBraveImporter
                    PasswordsDBDrop
                }
                Preferences.Section(title: "Reindex notes contents") {
                    ReindexNotesContents
                }
                Preferences.Section(title: "Rebuild notes contents") {
                    RebuildNotesContents
                }
                Preferences.Section(title: "Validate notes contents") {
                    ValidateNotesContents
                }
                Preferences.Section(title: "Create 100 random notes") {
                    Create100RandomNotes
                }
                Preferences.Section(title: "Create 10 random notes") {
                    Create10RandomNotes
                }
            }.onAppear {
                startObservers()
            }.onDisappear {
                stopObservers()
            }
        }.frame(maxHeight: 500)
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

    private var PnsViewEnabledCheckbox: some View {
        return Toggle(isOn: $showPNSView) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showPNSView].publisher.first()) {
                PreferencesManager.showPNSView = $0
            }
    }

    private var PnsJSEnabledCheckbox: some View {
        return Toggle(isOn: $pnsJSIsOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([pnsJSIsOn].publisher.first()) {
                PreferencesManager.PnsJSIsOn = $0
            }
    }

    private var BrowsingSessionCollectionCheckbox: some View {
        return Toggle(isOn: $browsingSessionCollectionIsOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([browsingSessionCollectionIsOn].publisher.first()) {
                PreferencesManager.browsingSessionCollectionIsOn = $0
            }
    }

    private var DebugSectionCheckbox: some View {
        return Toggle(isOn: $showDebugSection) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showDebugSection].publisher.first()) {
                PreferencesManager.showDebugSection = $0
            }
    }

    private var OmniboxScoreSectionCheckbox: some View {
        return Toggle(isOn: $showOmniboxScoreSection) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showOmniboxScoreSection].publisher.first()) {
                PreferencesManager.showOmniboxScoreSection = $0
            }
    }

    private var EnableTabGroupingWindowCheckbox: some View {
        return Toggle(isOn: $showTabGrougpingMenuItem) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showTabGrougpingMenuItem].publisher.first()) {
                PreferencesManager.showTabGrougpingMenuItem = $0
            }

    }

    private var AutomaticBackupBeforeUpdate: some View {
        return Toggle(isOn: $isDataBackupOnUpdateOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isDataBackupOnUpdateOn].publisher.first()) {
                PreferencesManager.isDataBackupOnUpdateOn = $0
            }
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

    private var ResetOnboarding: some View {
        Button(action: {
            Persistence.Authentication.hasSeenOnboarding = false
            AuthenticationManager.shared.username = nil
        }, label: {
            Text("Reset Onboarding").frame(minWidth: 100)
        })
    }

    private var ResetPrivateKey: some View {
        Button(action: {
            EncryptionManager.shared.resetPrivateKey()
            privateKey = EncryptionManager.shared.privateKey().asString()
        }, label: {
            // TODO: loc
            Text("Reset Private Key").frame(minWidth: 100)
        })
    }

    private var VerifyPrivateKey: some View {
        Button(action: {
            do {
                let string = "This is the clear text with accent é 🤤"
                let encryptedString = try EncryptionManager.shared.encryptString(string)
                var decryptedString: String?

                if let encryptedString = encryptedString {
                    decryptedString = try EncryptionManager.shared.decryptString(encryptedString)

                    if decryptedString == string, encryptedString != string {
                        UserAlert.showMessage(message: "Encryption",
                                              informativeText: "Encryption worked ✅ Clear text is \(string) and encrypted data is \(encryptedString)")

                        return
                    }
                }

                UserAlert.showError(message: "Encryption",
                                    informativeText: "This encryption didn't work, key is corrupted!")
            } catch {
                UserAlert.showError(message: "Encryption", error: error)
            }
        }, label: {
            // TODO: loc
            Text("Verify Private Key").frame(minWidth: 100)
        })
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
        Picker("", selection: $selectedDatabase.onChange(dbChange)) {
            ForEach(databases, id: \.id) {
                Text($0.title).tag($0)
            }
        }.labelsHidden()
        .frame(idealWidth: 100, maxWidth: 400)
    }

    private func dbChange(_ database: Database?) {
        guard let database = database else { return }
        DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
    }

    @State private var cancellables = [AnyCancellable]()

    private func startObservers() {
        NotificationCenter.default
            .publisher(for: .defaultDatabaseUpdate, object: nil)
            .sink { _ in
                selectedDatabase = Database.defaultDatabase()
            }
            .store(in: &cancellables)
        AuthenticationManager.shared.isAuthenticatedPublisher.receive(on: DispatchQueue.main).sink { isAuthenticated in
            loggedIn = isAuthenticated
        }.store(in: &cancellables)
    }
    private func stopObservers() {
        cancellables.removeAll()
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
                    try PasswordImporter.importPasswords(fromCSV: url)
                } catch {
                    Logger.shared.logError(String(describing: error), category: .general)
                }
            }
        }, label: {
            Text("Import Passwords CSV File")
        })
    }

    private var PasswordBraveImporter: some View {
        Button(action: {
            let importer = ChromiumPasswordImporter(browser: .brave)
            AppDelegate.main.data.importsManager.startBrowserPasswordImport(from: importer)
        }, label: {
            Text("Import Passwords from Brave Browser")
        })
    }

    private var PasswordsDBDrop: some View {
        Button(action: {
            PasswordManager.shared.markAllDeleted()
        }, label: {
            Text("Erase Passwords Database")
        })
    }

    private var ReindexNotesContents: some View {
        Button(action: { BeamNote.indexAllNotes() }, label: {
            Text("Reindex all notes' contents")
        })
    }

    private var RebuildNotesContents: some View {
        Button(action: { BeamNote.rebuildAllNotes() }, label: {
            Text("Rebuild all notes' contents")
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { BeamNote.validateAllNotes() }, label: {
            Text("Validate all notes' contents")
        })
    }

    private var Create100RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create100Notes()
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create100NormalNotes()
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create100JournalNotes()
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create10RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create10Notes()
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create10NormalNotes()
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.create10JournalNotes()
        }, label: {
            Text("Create 10 Random notes")
        })
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
                .onReceive([isCollectFeedbackEnabled].publisher.first()) {
                    PreferencesManager.isCollectFeedbackEnabled = $0
                }
            Toggle(isOn: $showsCollectFeedbackAlert) {
                Text("Show alert before sending collect feedback")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([showsCollectFeedbackAlert].publisher.first()) {
                    PreferencesManager.showsCollectFeedbackAlert = $0
                }
        }
    }

}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
