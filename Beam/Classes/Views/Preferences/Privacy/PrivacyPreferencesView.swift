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

            Preferences.Section(verticalAlignment: .top) {
            Text("Allowlist:")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 250, alignment: .trailing)
            } content: {
                AllowListSection(allowListIsPresented: $allowListIsPresented)
            }

//            Preferences.Section {
//                Text("Website Data:")
//                    .font(BeamFont.regular(size: 13).swiftUI)
//                    .foregroundColor(BeamColor.Generic.text.swiftUI)
//                    .frame(width: 250, alignment: .trailing)
//            } content: {
//                WebsiteDataSection()
//            }
        }
    }
}

struct PrivacyPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPreferencesView(selectedUpdate: .daily)
    }
}

struct AdsSection: View {
    @State private var isAdsFilterEnabled = PreferencesManager.isAdsFilterEnabled

    var body: some View {
        Toggle(isOn: $isAdsFilterEnabled) {
            Text("Remove most advertisements while browsing")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([isAdsFilterEnabled].publisher.first()) {
                PreferencesManager.isAdsFilterEnabled = $0
            }
    }
}

struct TrackersSection: View {
    @State private var isPrivacyFilterEnabled = PreferencesManager.isPrivacyFilterEnabled
    @State private var isSocialMediaFilterEnabled = PreferencesManager.isSocialMediaFilterEnabled

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $isPrivacyFilterEnabled) {
                Text("Prevent Internet history tracking")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([isPrivacyFilterEnabled].publisher.first()) {
                    PreferencesManager.isPrivacyFilterEnabled = $0
                }

            Toggle(isOn: $isSocialMediaFilterEnabled) {
                Text("Block Social Media Buttons")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([isSocialMediaFilterEnabled].publisher.first()) {
                    PreferencesManager.isSocialMediaFilterEnabled = $0
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
    @State private var isAnnoyancesFilterEnabled = PreferencesManager.isAnnoyancesFilterEnabled
    @State private var isCookiesFilterEnabled = PreferencesManager.isCookiesFilterEnabled

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $isAnnoyancesFilterEnabled) {
                Text("Remove banners and popups from websites")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([isAnnoyancesFilterEnabled].publisher.first()) {
                    PreferencesManager.isAnnoyancesFilterEnabled = $0
                }
            Toggle(isOn: $isCookiesFilterEnabled) {
                Text("Hide cookie banners")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onReceive([isCookiesFilterEnabled].publisher.first()) {
                    PreferencesManager.isCookiesFilterEnabled = $0
                }
            VStack {
                Text("Some websites display banners which impair the site’s functionality in order to force your content to be tracked.")
                    .font(BeamFont.regular(size: 11).swiftUI)
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
            Toggle(isOn: .constant(false)) {
                Text("Block All Cookies")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)

            HStack {
                Button("Manage Website Data...") {

                }
            }
        }
    }
}
