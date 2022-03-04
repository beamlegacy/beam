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
    @State private var localPrivateKey = ""
    @State private var privateKeys = [String: String]()
    @State private var stateRestorationEnabled = Configuration.stateRestorationEnabled
    @State private var loading: Bool = false

    @State var showPNSView = PreferencesManager.showPNSView
    @State var pnsJSIsOn = PreferencesManager.PnsJSIsOn
    @State var browsingSessionCollectionIsOn = PreferencesManager.browsingSessionCollectionIsOn
    @State var showDebugSection = PreferencesManager.showDebugSection
    @State var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @State var showTabGrougpingMenuItem = PreferencesManager.showTabGrougpingMenuItem
    @State var showTabsColoring = PreferencesManager.showTabsColoring
    @State var isDataBackupOnUpdateOn = PreferencesManager.isDataBackupOnUpdateOn
    @State var isDirectUploadOn = Configuration.beamObjectDataUploadOnSeparateCall
    @State var isDirectDownloadOn = Configuration.beamObjectDataOnSeparateCall
    @State var isWebsocketEnabled = Configuration.websocketEnabled
    @State var showWebOnLaunchIfTabs = PreferencesManager.showWebOnLaunchIfTabs

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
                Preferences.Section(title: "Network") {
                    NetworkEnabled
                }

                Preferences.Section(title: "Websocket") {
                    WebsocketEnabled
                }
                Preferences.Section(title: "Direct Upload") {
                    DirectUpload
                }
                Preferences.Section(title: "Direct Download") {
                    DirectDownload
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
                    Text(Configuration.Sentry.DSN)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                        .frame(maxWidth: 387)
                }

                Preferences.Section(title: "TabGrouping Window menu") {
                    EnableTabGroupingWindowCheckbox
                }
                Preferences.Section(title: "TabGrouping Colors", bottomDivider: true) {
                    EnableTabsColoringCheckbox
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
                                                DatabaseManager.dispatchDatabaseChangedNotification(beforeDb,
                                                                                                    DatabaseManager.defaultDatabase, andRestart: true)
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
                            AppDelegate.main.data.clusteringManager.addOrphanedUrlsFromCurrentSession(orphanedUrlManager: AppDelegate.main.data.clusteringOrphanedUrlManager)
                            AppDelegate.main.data.clusteringOrphanedUrlManager.export(to: url)
                            AppDelegate.main.data.clusteringManager.exportSession(sessionExporter: AppDelegate.main.data.sessionExporter, to: url)
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
                        DispatchQueue.global().async {
                            BrowsingTreeStoreManager.shared.legacyCleanup { _ in
                                self.loading = false
                            }
                        }
                    }, label: {
                        Text("Legacy browsing trees").frame(minWidth: 100)
                    }).disabled(loading)
                }

                Preferences.Section(title: "Encryption keys", bottomDivider: true) {
                    VStack(alignment: .leading) {
                        if AuthenticationManager.shared.isAuthenticated {
                            if privateKeys.isEmpty {
                                Button("Migrate old private key to current account") {
                                    migrateOldPrivateKeyToCurrentAccount()
                                }
                            } else {
                                ForEach(privateKeys.sorted(by: >), id: \.key) { key, value in
                                    VStack(alignment: .leading) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(key)
                                            Spacer()

                                            Button("Verify") {
                                                verifyPrivateKey(forAccount: key)
                                            }
                                            Button("Delete") {
                                                deletePrivateKey(forAccount: key)
                                            }.foregroundColor(Color.red)
                                            Button("Reset") {
                                                resetPrivateKey(forAccount: key)
                                            }.foregroundColor(Color.red)
                                        }
                                        TextField("\(key):", text: Binding<String>(get: {
                                            EncryptionManager.shared.readPrivateKey(for: key)?.asString() ?? "No private key"
                                        }, set: { value, _ in
                                            _ = try? EncryptionManager.shared.replacePrivateKey(for: key, with: value)
                                            updateKeys()
                                        }))
                                        Separator(horizontal: true, hairline: true)
                                    }.frame(width: 450)
                                }

                                Button("Delete all private keys") {
                                    deleteAllPrivateKeys()
                                }.foregroundColor(Color.red)
                            }
                        } else {
                            Text("You are not Authenticated")
                        }
                    }
                }

                Preferences.Section(title: "Local Encryption Key", bottomDivider: true) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Local private key (only used to store local contents)")
                            Spacer()

                                Button("Verify") {
                                    verifyLocalPrivateKey()
                                }
                                Button("Reset") {
                                    resetLocalPrivateKey()
                                }.foregroundColor(Color.red)
                        }.frame(width: 450)
                        TextField("local private key:", text: Binding<String>(get: {
                            localPrivateKey
                        }, set: { value, _ in
                            Persistence.Encryption.localPrivateKey = value
                            updateKeys()
                        })).frame(width: 450)
                        Spacer()

                        VStack(alignment: .leading) {
                            Text("The historical private key:")
                            TextField("privateKey", text: Binding<String>(get: {
                                Persistence.Encryption.privateKey ?? ""
                            }, set: { value, _ in
                                Persistence.Encryption.privateKey = value
                            }))
                        }.frame(width: 450)
                    }
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

                Preferences.Section(bottomDivider: true) {
                    Text("Show Web on launch with tabs")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    showWebOnLaunchIfTabsView
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
                if AuthenticationManager.shared.isAuthenticated {
                    updateKeys()
                }
            }.onDisappear {
                stopObservers()
            }
        }.frame(maxHeight: 500)
    }

    private func updateKeys() {
        var pkeys = [String: String]()
        for email in EncryptionManager.shared.accounts {
            pkeys[email] = EncryptionManager.shared.readPrivateKey(for: email)?.asString() ?? ""
        }
        privateKeys = pkeys
        localPrivateKey = EncryptionManager.shared.localPrivateKey().asString()
    }

    @State private var showNewDatabase = false

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

    private var EnableTabsColoringCheckbox: some View {
        return Toggle(isOn: $showTabsColoring) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showTabsColoring].publisher.first()) {
                PreferencesManager.showTabsColoring = $0
            }

    }

    private var DirectDownload: some View {
        return Toggle(isOn: $isDirectDownloadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isDirectDownloadOn].publisher.first()) {
                Configuration.beamObjectDataOnSeparateCall = $0
            }
    }

    private var DirectUpload: some View {
        return Toggle(isOn: $isDirectUploadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isDirectUploadOn].publisher.first()) {
                Configuration.beamObjectDataUploadOnSeparateCall = $0
            }
    }

    private var AutomaticBackupBeforeUpdate: some View {
        Toggle(isOn: $isDataBackupOnUpdateOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isDataBackupOnUpdateOn].publisher.first()) {
                PreferencesManager.isDataBackupOnUpdateOn = $0
            }
    }

    private var WebsocketEnabled: some View {
        Toggle(isOn: $isWebsocketEnabled) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isWebsocketEnabled, perform: {
                Configuration.websocketEnabled = $0
            })
    }

    private var NetworkEnabled: some View {
        Toggle(isOn: $networkEnabled) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: networkEnabled, perform: {
                Configuration.networkEnabled = $0
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

    private var ResetOnboarding: some View {
        Button(action: {
            Persistence.Authentication.hasSeenOnboarding = false
            AuthenticationManager.shared.username = nil
        }, label: {
            Text("Reset Onboarding").frame(minWidth: 100)
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
        NotificationCenter.default
            .publisher(for: .databaseListUpdate, object: nil)
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

    func deletePrivateKey(forAccount key: String) {
        UserAlert.showAlert(message: "Are you sure you want to erase the private key for '\(key)'?", buttonTitle: "Cancel", secondaryButtonTitle: "Erase Private Key", secondaryButtonAction: {
            EncryptionManager.shared.clearPrivateKey(for: key)
            updateKeys()
        }, style: .critical)
    }

    func resetPrivateKey(forAccount key: String) {
        UserAlert.showAlert(message: "Are you sure you want to reset the private key for '\(key)'?", buttonTitle: "Cancel", secondaryButtonTitle: "Reset Private Key", secondaryButtonAction: {
            EncryptionManager.shared.clearPrivateKey(for: key)
            let pkey = EncryptionManager.shared.generateKey()
            do {
                try EncryptionManager.shared.replacePrivateKey(for: key, with: pkey.asString())
            } catch {
                Logger.shared.logError("Error while replacing the private key for \(key) with \(pkey.asString())", category: .encryption)
            }
            updateKeys()
        }, style: .critical)
    }

    func verifyPrivateKey(forAccount key: String) {
        do {
            let string = "This is the clear text with accent é 🤤"
            let PKey = EncryptionManager.shared.privateKey(for: key)
            let encryptedString = try EncryptionManager.shared.encryptString(string, PKey)
            var decryptedString: String?

            if let encryptedString = encryptedString {
                decryptedString = try EncryptionManager.shared.decryptString(encryptedString, PKey)

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
    }

    func resetLocalPrivateKey() {
        UserAlert.showAlert(message: "Are you sure you want to reset the local private key?", buttonTitle: "Cancel", secondaryButtonTitle: "Reset Local Private Key", secondaryButtonAction: {
            let pkey = EncryptionManager.shared.generateKey()
            Persistence.Encryption.localPrivateKey = pkey.asString()
            updateKeys()
        }, style: .critical)
    }

    func verifyLocalPrivateKey() {
        do {
            let string = "This is the clear text with accent é 🤤"
            let PKey = EncryptionManager.shared.localPrivateKey()
            let encryptedString = try EncryptionManager.shared.encryptString(string, PKey)
            var decryptedString: String?

            if let encryptedString = encryptedString {
                decryptedString = try EncryptionManager.shared.decryptString(encryptedString, PKey)

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
    }

    func deleteAllPrivateKeys() {
        UserAlert.showAlert(message: "Are you sure you want to delete ALL private keys?", informativeText: "Erase all private keys", buttonTitle: "Cancel", secondaryButtonTitle: "Erase Private Keys", secondaryButtonAction: {
            EncryptionManager.shared.resetPrivateKeys(andMigrateOldSharedKey: false)
            updateKeys()
        }, style: .critical)
    }

    func migrateOldPrivateKeyToCurrentAccount() {
        _ = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        updateKeys()
    }

    private var showWebOnLaunchIfTabsView: some View {
        return Toggle(isOn: $showWebOnLaunchIfTabs) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([showWebOnLaunchIfTabs].publisher.first()) {
                PreferencesManager.showWebOnLaunchIfTabs = $0
            }
    }
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
