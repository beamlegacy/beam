import SwiftUI
import Preferences
import Sentry
import Combine

/**
Function wrapping SwiftUI into `PreferencePane`, which is mimicking view controller's default construction syntax.
*/
let AdvancedPreferencesViewController: () -> PreferencePane = {
    /// Wrap your custom view into `Preferences.Pane`, while providing necessary toolbar info.
    let paneView = Preferences.Pane(
        identifier: .advanced,
        title: "Advanced",
        toolbarIcon: NSImage(named: "gearshape.2")!
    ) {
        AdvancedPreferencesView()
            .environment(\.managedObjectContext, CoreDataManager.shared.mainContext)
    }

    return Preferences.PaneHostingController(pane: paneView)
}

struct AdvancedPreferencesView: View {
    @State private var apiHostname: String = Configuration.apiHostname
    @State private var publicHostname: String = Configuration.publicHostname
    @State private var bundleIdentifier: String = Configuration.bundleIdentifier
    @State private var env: String = Configuration.env
    @State private var sparkleUpdate: Bool = Configuration.sparkleUpdate
    @State private var sparkleFeedURL = Configuration.sparkleFeedURL
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
                  sortDescriptors: [NSSortDescriptor(keyPath: \Database.title, ascending: true)])
    var databases: FetchedResults<Database>

    private let contentWidth: Double = 650.0

    var body: some View {
        let apiHostnameBinding = Binding<String>(get: {
            self.apiHostname
        }, set: {
            self.apiHostname = $0
            Configuration.apiHostname = $0
        })

        let privateKeyBinding = Binding<String>(get: {
            privateKey
        }, set: {
            try? EncryptionManager.shared.replacePrivateKey($0)
        })

        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Bundle identifier:") {
                Text(bundleIdentifier)
            }
            Preferences.Section(title: "API endpoint:") {
                TextField("api hostname", text: apiHostnameBinding)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
            }
            Preferences.Section(title: "Public endpoint:") {
                Text(publicHostname)
            }
            Preferences.Section(title: "Environment:") {
                Text(env)
            }
            Preferences.Section(title: "CoreData:") {
                Text(CoreDataManager.shared.storeURL?.absoluteString ?? "-").fixedSize(horizontal: false, vertical: true)
            }
            Preferences.Section(title: "Sparkle Automatic Update:") {
                Text(String(describing: sparkleUpdate))
            }
            Preferences.Section(title: "Sparkle URL:") {
                Text(String(describing: sparkleFeedURL)).fixedSize(horizontal: false, vertical: true)
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
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
