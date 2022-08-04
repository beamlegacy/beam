//
//  PrivacyView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/06/2021.
//

import SwiftUI

struct PrivacyPreferencesView: View {
    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            ForEach(0..<getSettingsRows().count, id: \.self) { index in
                getSettingsRows()[index]
            }
        }
    }

    private func getSettingsRows() -> [Settings.Row] {
        [websiteTrackingRow, adsRow, trackersRow, annoyancesRow, updateRulesRow, allowListRow]
    }

    private var websiteTrackingRow: Settings.Row {
        Settings.Row {
            Text("Website tracking:")
        } content: {
            CrossSiteTrackingSection()
        }
    }

    private var adsRow: Settings.Row {
        Settings.Row {
            Text("Ads:")
        } content: {
            AdsSection()
        }
    }

    private var trackersRow: Settings.Row {
        Settings.Row {
            Text("Trackers:")
        } content: {
            TrackersSection()
        }
    }

    private var annoyancesRow: Settings.Row {
        Settings.Row {
            Text("Annoyances:")
        } content: {
            AnnoyancesSection()
        }
    }

    private var updateRulesRow: Settings.Row {
        Settings.Row {
            Text("Updates Rules:")
        } content: {
            UpdateRulesSection()
        }
    }

    private var allowListRow: Settings.Row {
        Settings.Row {
            Text("Allow list:")
        } content: {
            AllowListSection()
        }
    }
}

struct PrivacyPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPreferencesView()
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
            .onChange(of: isAdsFilterEnabled) {
                PreferencesManager.isAdsFilterEnabled = $0
            }
    }
}

struct CrossSiteTrackingSection: View {
    @State private var isCrossSiteTrackingEnabled = PreferencesManager.isCrossSiteTrackingEnabled

    var body: some View {
        Toggle(isOn: $isCrossSiteTrackingEnabled) {
            Text("Prevent cross-site tracking")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: isCrossSiteTrackingEnabled) {
                PreferencesManager.isCrossSiteTrackingEnabled = $0
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
                .onChange(of: isPrivacyFilterEnabled) {
                    PreferencesManager.isPrivacyFilterEnabled = $0
                }

            Toggle(isOn: $isSocialMediaFilterEnabled) {
                Text("Block Social Media Buttons")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: isSocialMediaFilterEnabled) {
                    PreferencesManager.isSocialMediaFilterEnabled = $0
                }

            VStack {
                Settings.SubtitleLabel("Websites which embed social media buttons implicitly track your browser history, even if you don’t have an account.")
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
                .onChange(of: isAnnoyancesFilterEnabled) {
                    PreferencesManager.isAnnoyancesFilterEnabled = $0
                }

            Toggle(isOn: $isCookiesFilterEnabled) {
                Text("Hide cookie banners")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: isCookiesFilterEnabled) {
                    PreferencesManager.isCookiesFilterEnabled = $0
                }

            VStack {
                Settings.SubtitleLabel("Some websites display banners which impair the site’s functionality in order to force your content to be tracked.")
                    .padding(.leading, 18)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }.frame(width: 279, height: 45, alignment: .center)
        }.padding(.bottom)
    }
}

struct UpdateRulesSection: View {
    @State private var selectedUpdate: SynchronizeInterval = ContentBlockingManager.shared.radBlockPreferences.synchronizeInterval

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Update Rules", selection: $selectedUpdate) {
                    ForEach(SynchronizeInterval.allCases, id: \.self) {
                        Text($0.name)
                    }
                }.labelsHidden()
                .frame(width: 140)
                .onChange(of: selectedUpdate) {
                    ContentBlockingManager.shared.radBlockPreferences.synchronizeInterval = $0
                }
                Button("Update Now") {
                    ContentBlockingManager.shared.synchronize()
                }
            }
            Settings.SubtitleLabel("Last updated: \(ContentBlockingManager.shared.radBlockPreferences.lastSynchronizationDate).")
        }
    }
}

struct AllowListSection: View {
    @State private var allowListIsPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Button("Manage...") {
                allowListIsPresented = true
            }.sheet(isPresented: $allowListIsPresented) {
                AllowListModalView().frame(width: 568, height: 422, alignment: .center)
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
