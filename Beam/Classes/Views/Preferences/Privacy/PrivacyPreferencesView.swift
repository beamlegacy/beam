//
//  PrivacyView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/06/2021.
//

import SwiftUI
import Preferences

let PrivacyPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .privacy, title: "Privacy", imageName: "preferences-privacy") {
    PrivacyPreferencesView(selectedUpdate: ContentBlockingManager.shared.radBlockPreferences.synchronizeInterval)
}

struct PrivacyPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    @State var allowListIsPresented: Bool = false
    @State var selectedUpdate: SynchronizeInterval

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section {
                Text("Ads:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                AdsSection()
            }
            Preferences.Section {
                Text("Trackers:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                TrackersSection()
            }

            Preferences.Section {
                Text("Annoyances:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                AnnoyancesSection()
            }

            Preferences.Section {
                Text("Updates Rules:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                UpdateRulesSection(selectedUpdate: $selectedUpdate)
            }

            Preferences.Section(bottomDivider: true) {
            Text("Allowlist:")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 250, alignment: .trailing)
            } content: {
                AllowListSection(allowListIsPresented: $allowListIsPresented)
            }

            Preferences.Section {
                Text("Website Data:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                WebsiteDataSection()
            }
        }
    }
}

struct PrivacyPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPreferencesView(selectedUpdate: .daily)
    }
}

struct AdsSection: View {
    var body: some View {
        Checkbox(checkState: PreferencesManager.isAdsFilterEnabled, text: "Remove most advertisments while browsing", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.isAdsFilterEnabled = activated
        }
    }
}

struct TrackersSection: View {
    var body: some View {
        VStack(alignment: .leading) {
            Checkbox(checkState: PreferencesManager.isPrivacyFilterEnabled, text: "Prevent Internet history tracking", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.isPrivacyFilterEnabled = activated
                if !activated && PreferencesManager.isSocialMediaFilterEnabled {
                    PreferencesManager.isSocialMediaFilterEnabled = false
                }
            }
            Checkbox(checkState: PreferencesManager.isSocialMediaFilterEnabled, text: "Block Social Media Buttons", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.isSocialMediaFilterEnabled = activated
            }
            VStack {
                Text("Websites which embed social media buttons implicitly track your browser history, even if you don’t have an account.")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
                    .padding(.leading, 22)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }.frame(width: 279, height: 45, alignment: .leading)
        }.padding(.bottom)
    }
}

struct AnnoyancesSection: View {
    var body: some View {
        VStack(alignment: .leading) {
            Checkbox(checkState: PreferencesManager.isAnnoyancesFilterEnabled, text: "Remove banners and popups from websites", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.isAnnoyancesFilterEnabled = activated
                if !activated && PreferencesManager.isCookiesFilterEnabled {
                    PreferencesManager.isCookiesFilterEnabled = false
                }
            }
            Checkbox(checkState: PreferencesManager.isCookiesFilterEnabled, text: "Hide cookie banners", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                PreferencesManager.isCookiesFilterEnabled = activated
            }
            VStack {
                Text("Some websites display banners which impair the site’s functionality in order to force your content to be tracked.")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
                    .padding(.leading, 18)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }.frame(width: 279, height: 45, alignment: .center)
        }.padding(.bottom)
    }
}

struct UpdateRulesSection: View {
    @Binding var selectedUpdate: SynchronizeInterval

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Update Rules", selection: $selectedUpdate) {
                    ForEach(SynchronizeInterval.allCases, id: \.self) {
                        Text($0.name)
                    }
                }.labelsHidden()
                .frame(width: 140)
                .onReceive([self.selectedUpdate].publisher.first()) { (value) in
                    ContentBlockingManager.shared.radBlockPreferences.synchronizeInterval = value
                }
                Button("Update Now") {
                    ContentBlockingManager.shared.synchronize()
                }
            }
            Text("Last updated: \(ContentBlockingManager.shared.radBlockPreferences.lastSynchronizationDate)")
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
        }
    }
}

struct AllowListSection: View {
    @Binding var allowListIsPresented: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Button("Manage...") {
                allowListIsPresented = true
            }.sheet(isPresented: $allowListIsPresented) {
                let allowListViewModel = AllowListViewModel()
                AllowListModalView(viewModel: allowListViewModel).frame(width: 568, height: 422, alignment: .center)
            }
            // TODO
            //                    Text("You can temporarily whitelist a site by holding the reload button in Beam’s navigation bar and selecting “Reload Without Content Blockers”.")
            //                        .font(BeamFont.regular(size: 11).swiftUI)
            //                        .multilineTextAlignment(.leading)
            //                        .lineLimit(nil)
            //                        .frame(width: 279, alignment: .center)
            //                        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
        }
    }
}

struct WebsiteDataSection: View {
    var body: some View {
        VStack(alignment: .leading) {
            Checkbox(checkState: false, text: "Block All Cookies", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { _ in }
            HStack {
                Button("Manage Website Data...") {

                }
            }
        }
    }
}
