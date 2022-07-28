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
struct AdvancedPreferencesView: View, BeamDocumentSource {
    public static var sourceId: String { "\(Self.self)"}

    @State private var apiHostname: String = Configuration.apiHostname
    @State private var restApiHostname: String = Configuration.restApiHostname
    @State private var publicAPIpublishServer: String = Configuration.publicAPIpublishServer
    @State private var publicAPIembed: String = Configuration.publicAPIembed
    @State private var bundleIdentifier: String = Configuration.bundleIdentifier
    @State private var env: String = Configuration.env.rawValue
    @State private var autoUpdate: Bool = Configuration.autoUpdate
    @State private var updateFeedURL = Configuration.updateFeedURL
    @State private var sentryEnabled = Configuration.sentryEnabled
    @State private var loggedIn: Bool = AuthenticationManager.shared.isAuthenticated
    @State private var networkEnabled: Bool = Configuration.networkEnabled
    @State private var privateKeys = [String: String]()
    @State private var stateRestorationEnabled = Configuration.stateRestorationEnabled
    @State private var loading: Bool = false
    @State private var showPrivateKeysSection = false
    @State private var dailyStatsExportDaysAgo: String = "0"
    @State private var passwordSanityReport = ""

    @State private var showPNSView = PreferencesManager.showPNSView
    @State private var pnsJSIsOn = PreferencesManager.PnsJSIsOn
    @State private var browsingSessionCollectionIsOn = PreferencesManager.browsingSessionCollectionIsOn
    @State private var showDebugSection = PreferencesManager.showDebugSection
    @State private var showOmniboxScoreSection = PreferencesManager.showOmniboxScoreSection
    @State private var showClusteringSettingsMenu = PreferencesManager.showClusteringSettingsMenu
    @State private var isDataBackupOnUpdateOn = PreferencesManager.isDataBackupOnUpdateOn
    @State private var isDirectUploadOn = Configuration.beamObjectDataUploadOnSeparateCall
    @State private var isDirectUploadNIOOn = Configuration.directUploadNIO
    @State private var isDirectUploadAllObjectsOn = Configuration.directUploadAllObjects
    @State private var isDirectDownloadOn = Configuration.beamObjectDataOnSeparateCall
    @State private var isWebsocketEnabled = Configuration.websocketEnabled
    @State private var restBeamObject = Configuration.beamObjectOnRest
    @State private var createJournalOncePerWindow = PreferencesManager.createJournalOncePerWindow
    @State private var useSidebar = PreferencesManager.useSidebar
    @State private var includeHistoryContentsInOmniBox = PreferencesManager.includeHistoryContentsInOmniBox
    @State private var enableOmnibeams = PreferencesManager.enableOmnibeams
    @State private var enableDailySummary = PreferencesManager.enableDailySummary

    // Database
    @State private var newDatabaseTitle = ""
    @State private var selectedDatabase = BeamData.shared.currentDatabase
    var databases: [BeamDatabase] {
        BeamData.shared.currentAccount?.allDatabases ?? []
    }

    private let contentWidth: Double = PreferencesManager.contentWidth

    private var apiHostnameBinding: Binding<String> { Binding<String>(get: {
        self.apiHostname
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiHostname = cleanValue
        Configuration.apiHostname = cleanValue
    })}

    private var restApiHostnameBinding: Binding<String> { Binding<String>(get: {
        self.restApiHostname
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.restApiHostname = cleanValue
        Configuration.restApiHostname = cleanValue
    })}

    private var publicAPIpublishServerBinding: Binding<String> { Binding<String>(get: {
        self.publicAPIpublishServer
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicAPIpublishServer = cleanValue
        Configuration.publicAPIpublishServer = cleanValue
    })}

    private var publicAPIembedBinding: Binding<String> { Binding<String>(get: {
        self.publicAPIembed
    }, set: {
        let cleanValue = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publicAPIembed = cleanValue
        Configuration.publicAPIembed = cleanValue
    })}

    var body: some View {
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
                    Text("API endpoints")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    TextField("API hostname", text: apiHostnameBinding)
                        .lineLimit(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
                    TextField("REST API hostname", text: restApiHostnameBinding)
                        .lineLimit(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 286)
                }
                Preferences.Section {
                    Text("Public API publish server:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    TextField("public api publish server", text: publicAPIpublishServerBinding)
                        .lineLimit(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
                }
                Preferences.Section {
                    Text("Public API embed server:")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    TextField("public api embed server", text: publicAPIembedBinding)
                        .lineLimit(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
                }
                Preferences.Section {
                    Text("")
                } content: {
                    ResetAPIEndpointsButton
                    SetAPIEndPointsToStagingButton
                    SetAPIEndPointsToLocal
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
                Preferences.Section(title: "Direct Upload/Download use NIO (requires resync from scratch)") {
                    DirectUploadNIO
                }
                Preferences.Section(title: "Direct Upload All Objects (requires resync from scratch)") {
                    DirectUploadAllObjects
                }

                Preferences.Section(title: "Direct Download") {
                    DirectDownload
                }
                Preferences.Section(title: "REST API") {
                    RestBeamObject
                }
                Preferences.Section(title: "", bottomDivider: true) {
                    Button(action: {
                        self.loading = true
                        Persistence.Sync.BeamObjects.last_received_at = nil
                        Persistence.Sync.BeamObjects.last_updated_at = nil
                        Task { @MainActor in
                            do {
                                _ = try await AppDelegate.main.syncDataWithBeamObject(force: true)
                            } catch {
                                Logger.shared.logError("Error while syncing data: \(error)", category: .document)
                            }
                            self.loading = false
                        }
                    }, label: {
                        Text("Force full sync").frame(minWidth: 100)
                    })
                    .disabled(loading)

                    Button(action: {
                        do {
                            try BeamData.shared.currentAccount?.documentSynchroniser?.forceReceiveAll()
                        } catch {
                            Logger.shared.logError("Error while force recieve all document: \(error)", category: .document)
                        }
                    }, label: {
                        Text("Force Receive All Document").frame(minWidth: 100)
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

                Preferences.Section(title: "Clustering Settings menu", bottomDivider: true) {
                    EnableClusteringSettingsCheckbox
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
                                // TODO: Fix Database operation with the new BeamDatabase objects
//                                let beforeDb = DatabaseManager.defaultDatabase
//                                if !newDatabaseTitle.isEmpty {
//                                    let database = DatabaseStruct(title: newDatabaseTitle)
//                                    databaseManager.save(database, completion: { result in
//                                        if case .success(let done) = result, done {
//
//                                            if let database = try? Database.fetchWithId(CoreDataManager.shared.mainContext, database.id) {
//                                                DatabaseManager.defaultDatabase = DatabaseStruct(database: database)
//                                                selectedDatabase = database
//                                                try? CoreDataManager.shared.save()
//                                                DatabaseManager.dispatchDatabaseChangedNotification(beforeDb,
//                                                                                                    DatabaseManager.defaultDatabase, andRestart: true)
//                                            }
//                                        }
//                                        showNewDatabase = false
//                                    })
//                                } else {
//                                    showNewDatabase = false
//                                }
//                                newDatabaseTitle = ""
                            }, label: {
                                Text("Create")
                            }).padding()
                        }
                    }
                    Button(action: {
                        DispatchQueue.global(qos: .userInteractive).async {
                            do {
                                try BeamData.shared.currentAccount?.deleteEmptyDatabases()
                                AppDelegate.showMessage("Empty databases deleted")
                            } catch {
                                DispatchQueue.main.async {
                                    AppDelegate.showError(error)
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
                            BeamData.shared.clusteringManager.addOrphanedUrlsFromCurrentSession(orphanedUrlManager: BeamData.shared.clusteringOrphanedUrlManager)
                            BeamData.shared.clusteringOrphanedUrlManager.export(to: url)
                            BeamData.shared.clusteringManager.exportSession(sessionExporter: BeamData.shared.sessionExporter, to: url, correctedPages: nil)
                        }
                    }, label: {
                        Text("Note Sources").frame(minWidth: 100)
                    })

                    Button(action: {

                    }, label: {
                        Text("Browsing Sessions").frame(minWidth: 100)
                    })
                }

                Preferences.Section(title: "Cleanup ", bottomDivider: true) {
                    Button(action: {
                        guard let collection = BeamData.shared.currentDocumentCollection else { return }
                        try? collection
                            .fetchIds(filters: [])
                            .forEach {
                                let note = BeamNote.fetch(id: $0, keepInMemory: false)
                                _ = note?.save(self)
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
                        Button("Delete all private keys") {
                            deleteAllPrivateKeys()
                        }.foregroundColor(Color.red)
                        if AuthenticationManager.shared.isAuthenticated {
                            if privateKeys.isEmpty {
                                Button("Migrate old private key to current account") {
                                    migrateOldPrivateKeyToCurrentAccount()
                                }
                            } else {
                                Button(showPrivateKeysSection ? "Hide private keys" : "Show private keys") {
                                    showPrivateKeysSection = !showPrivateKeysSection
                                }
                                if showPrivateKeysSection {
                                    ForEach(privateKeys.sorted(by: >), id: \.key) { key, value in
                                    VStack(alignment: .leading) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(key)
                                            Spacer()
                                        }
                                        Button("Verify") {
                                            verifyPrivateKey(forAccount: key)
                                        }
                                        Button("Delete") {
                                            deletePrivateKey(forAccount: key)
                                        }.foregroundColor(Color.red)
                                        Button("Reset") {
                                            resetPrivateKey(forAccount: key)
                                        }.foregroundColor(Color.red)
                                        TextField("\(key):", text: Binding<String>(get: {
                                            EncryptionManager.shared.readPrivateKey(for: key)?.asString() ?? "No private key"
                                        }, set: { value, _ in
                                            _ = try? EncryptionManager.shared.replacePrivateKey(for: key, with: value)
                                            updateKeys()
                                        }))
                                        Separator(horizontal: true, hairline: true)
                                    }.frame(width: 450)
                                }

                                }
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
                            Persistence.Encryption.localPrivateKey ?? ""
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
                        Spacer()

                        Button("Verify Passwords") {
                            verifyPasswords()
                        }
                        Text(passwordSanityReport)
                            .frame(width: 450)
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

                Preferences.Section(bottomDivider: false) {
                    Text("Show frecency / score in Omnibox")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    OmniboxScoreSectionCheckbox
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Include history contents in Omnibox")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    HistoryInOmniboxCheckbox
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Omnibeams")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    OmnibeamsCheckbox
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
                    Text("Create the journal views once (needs restart")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    createJournalOncePerWindowView
                }

                Preferences.Section(bottomDivider: true) {
                    Text("Use sidebar")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                } content: {
                    useSidebarView
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
                Preferences.Section(title: "Create 10 random notes", bottomDivider: true) {
                    Create10RandomNotes
                }
                Preferences.Section(title: "Daily Summary", bottomDivider: true) {
                    enableDailySummaryView
                }
                Preferences.Section(title: "Daily Summary Debug: ") {
                    HStack {
                        TextField("", text: $dailyStatsExportDaysAgo)
                            .frame(width: 50, height: 25, alignment: .center)
                        Text("Days ago")
                    }
                    ExportDailyUrlStats
                    ExportDailyNoteStats
                }
            }.onAppear {
                startObservers()
                if AuthenticationManager.shared.isAuthenticated {
                    showPrivateKeysSection = false
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
    }

    @State private var showNewDatabase = false

    private var PnsViewEnabledCheckbox: some View {
        return Toggle(isOn: $showPNSView) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showPNSView) {
                PreferencesManager.showPNSView = $0
            }
    }

    private var PnsJSEnabledCheckbox: some View {
        return Toggle(isOn: $pnsJSIsOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: pnsJSIsOn) {
                PreferencesManager.PnsJSIsOn = $0
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

    private var DebugSectionCheckbox: some View {
        return Toggle(isOn: $showDebugSection) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: showDebugSection) {
                PreferencesManager.showDebugSection = $0
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

    private var DirectDownload: some View {
        return Toggle(isOn: $isDirectDownloadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDirectDownloadOn) {
                Configuration.beamObjectDataOnSeparateCall = $0
            }
    }

    private var DirectUpload: some View {
        return Toggle(isOn: $isDirectUploadOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDirectUploadOn) {
                Configuration.beamObjectDataUploadOnSeparateCall = $0
            }
    }

    private var DirectUploadNIO: some View {
        return Toggle(isOn: $isDirectUploadNIOOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDirectUploadNIOOn) {
                Configuration.directUploadNIO = $0
            }
    }

    private var DirectUploadAllObjects: some View {
        return Toggle(isOn: $isDirectUploadAllObjectsOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isDirectUploadAllObjectsOn].publisher.first()) {
                Configuration.directUploadAllObjects = $0
            }
    }

    private var RestBeamObject: some View {
        return Toggle(isOn: $restBeamObject) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: restBeamObject) {
                Configuration.beamObjectOnRest = $0
            }
    }

    private var AutomaticBackupBeforeUpdate: some View {
        Toggle(isOn: $isDataBackupOnUpdateOn) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isDataBackupOnUpdateOn) {
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
            restApiHostname = Configuration.restApiHostname
            publicAPIpublishServer = Configuration.publicAPIpublishServer
            publicAPIembed = Configuration.publicAPIembed
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Reset API Endpoints").frame(minWidth: 100)
        })
    }

    private var SetAPIEndPointsToStagingButton: some View {
        Button(action: {
            Configuration.setAPIEndPointsToStaging()
            apiHostname = Configuration.apiHostname
            restApiHostname = Configuration.restApiHostname
            publicAPIpublishServer = Configuration.publicAPIpublishServer
            publicAPIembed = Configuration.publicAPIembed
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Set API Endpoints to staging server").frame(minWidth: 100)
        })
    }

    private var SetAPIEndPointsToLocal: some View {
        Button(action: {
            Configuration.setAPIEndPointsToDevelopment()
            apiHostname = Configuration.apiHostname
            restApiHostname = Configuration.restApiHostname
            promptEraseAllDataAlert()
        }, label: {
            // TODO: loc
            Text("Set API Endpoints to local server").frame(minWidth: 100)
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

    private func dbChange(_ database: BeamDatabase?) {
        guard let database = database else { return }
        try? BeamData.shared.setCurrentDatabase(database)
    }

    @State private var cancellables = [AnyCancellable]()

    private func startObservers() {
        BeamData.shared.$currentDatabase
            .sink { _ in
                selectedDatabase = BeamData.shared.currentDatabase
            }
            .store(in: &cancellables)
        BeamData.shared.currentAccount?.$allDatabases
            .sink { _ in
                selectedDatabase = BeamData.shared.currentDatabase
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
            BeamData.shared.importsManager.startBrowserPasswordImport(from: importer)
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
        Button(action: { BeamNote.indexAllNotes(interactive: true) }, label: {
            Text("Reindex all notes' contents")
        })
    }

    private var RebuildNotesContents: some View {
        Button(action: { try? BeamNote.rebuildAllNotes(self, interactive: true) }, label: {
            Text("Rebuild all notes' contents")
        })
    }

    private var ValidateNotesContents: some View {
        Button(action: { try? BeamNote.validateAllNotes(interactive: true) }, label: {
            Text("Validate all notes' contents")
        })
    }

    private var Create100RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 0.2, futureRatio: 0.1)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 0.0, futureRatio: 0.0)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create100JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 100, journalRatio: 1.0, futureRatio: 0.05)
        }, label: {
            Text("Create 100 Random notes")
        })
    }

    private var Create10RandomNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 0.2, futureRatio: 0.05)
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10NormalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 0.0, futureRatio: 0.0)
        }, label: {
            Text("Create 10 Random notes")
        })
    }

    private var Create10JournalNotes: some View {
        Button(action: {
            BeamUITestsMenuGenerator.createNotes(count: 10, journalRatio: 1.0, futureRatio: 0.05)
        }, label: {
            Text("Create 10 Random notes")
        })
    }
    private var ExportDailyNoteStats: some View {
        Button(action: {
            let panel = NSSavePanel()
            let daysAgo = Int(dailyStatsExportDaysAgo) ?? 0
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = DailyStatsExporter.noteStatsDefaultFileName(daysAgo: daysAgo)
            panel.showsTagField = false
            panel.begin { (result) in
                guard result == .OK, let url = panel.url else {
                    panel.close()
                    return
                }
                DailyStatsExporter.exportNoteStats(daysAgo: daysAgo, to: url)
            }
        }, label: {
            Text("Export note stats").frame(minWidth: 100)
        })
    }
    private var ExportDailyUrlStats: some View {
        Button(action: {
            let panel = NSSavePanel()
            let daysAgo = Int(dailyStatsExportDaysAgo) ?? 0
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = DailyStatsExporter.urlStatsDefaultFileName(daysAgo: daysAgo)
            panel.showsTagField = false
            panel.begin { (result) in
                guard result == .OK, let url = panel.url else {
                    panel.close()
                    return
                }
                DailyStatsExporter.exportUrlStats(daysAgo: daysAgo, to: url)
            }
        }, label: {
            Text("Export url stats").frame(minWidth: 100)
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

    private func verifyPasswords() {
        do {
            let sanityDigest = try PasswordManager.shared.sanityDigest()
            passwordSanityReport = sanityDigest.description
        } catch {
            passwordSanityReport = error.localizedDescription
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

    private var createJournalOncePerWindowView: some View {
        return Toggle(isOn: $createJournalOncePerWindow) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: createJournalOncePerWindow) {
                PreferencesManager.createJournalOncePerWindow = $0
            }
    }

    private var useSidebarView: some View {
        return Toggle(isOn: $useSidebar) {
            Text("Enabled")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: useSidebar) {
                PreferencesManager.useSidebar = $0
            }
    }

    private var enableDailySummaryView: some View {
        return Toggle(isOn: $enableDailySummary) {
            Text("Enable")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: enableDailySummary) {
                PreferencesManager.enableDailySummary = $0
            }
    }

    private func promptEraseAllDataAlert() {
        let alert = NSAlert()
        alert.messageText = "Do you want to erase all local data?"
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 16))
        alert.accessoryView = customView
        alert.addButton(withTitle: "Erase all data")
        alert.addButton(withTitle: "Close")
        alert.alertStyle = .warning
        guard let window = AdvancedPreferencesViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            for window in AppDelegate.main.windows {
                window.state.closeAllTabs(closePinnedTabs: true)
            }
            AppDelegate.main.deleteAllLocalData()
        }
    }

    private func promptExportBrowsingSessions() {
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
    }
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
