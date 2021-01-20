import SwiftUI
import Preferences
import Sentry

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

    private let contentWidth: Double = 450.0

    var body: some View {
        let binding = Binding<String>(get: {
            self.apiHostname
        }, set: {
            self.apiHostname = $0
            Configuration.apiHostname = $0
        })

        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Bundle identifier:") {
                Text(bundleIdentifier)
            }
            Preferences.Section(title: "API endpoint:") {
                TextField("api hostname", text: binding).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 200)
            }
            Preferences.Section(title: "Public endpoint:") {
                Text(publicHostname)
            }
            Preferences.Section(title: "Environment:") {
                Text(env)
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
                Text("https://\(Configuration.sentryKey)@\(Configuration.sentryHostname)/\(Configuration.sentryProject)").fixedSize(horizontal: false, vertical: true)
            }
            Preferences.Section(title: "Actions") {
                ResetAPIEndpointsButton
                CrashButton
                CopyAccessToken
            }
        }
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
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
