import SwiftUI
import Sentry
import Combine
import BeamCore

struct AdvancedPreferencesView: View {
    var body: some View {
        SwiftUI.TabView {
            AdvancedPreferencesGeneral()
                .tabItem {
                    Text("General")
                }
            AdvancedPreferencesNetwork()
                .tabItem {
                    Text("Network")
                }
            AdvancedPreferencesDatabase()
                .tabItem {
                    Text("Database")
                }
            AdvancedPreferencesAutoUpdate()
                .tabItem {
                    Text("AutoUpdate")
                }
            AdvancedPreferencesPrivateKeys()
                .tabItem {
                    Text("Private Keys")
                }
            AdvancedPreferencesJournalAndNotes()
                .tabItem {
                    Text("Journal & Notes")
                }
            AdvancedPreferencesMisc()
                .tabItem {
                    Text("Misc.")
                }
        }.padding()
    }
}

struct AdvancedPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedPreferencesView()
    }
}
