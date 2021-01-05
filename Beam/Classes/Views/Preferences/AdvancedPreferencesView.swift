import SwiftUI
import Preferences

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

    private let contentWidth: Double = 450.0

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Bundle identifier:") {
                Text(bundleIdentifier)
            }
            Preferences.Section(title: "API endpoint:") {
                Text(apiHostname)
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

            Preferences.Section(title: "Actions") {
                ResetAPIEndpointsButton
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
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
