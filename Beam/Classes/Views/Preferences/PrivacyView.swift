//
//  PrivacyView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/06/2021.
//

import SwiftUI
import Preferences

/**
 Function wrapping SwiftUI into `PreferencePane`, which is mimicking view controller's default construction syntax.
 */
let PrivacyPreferenceViewController: () -> PreferencePane = {
    /// Wrap your custom view into `Preferences.Pane`, while providing necessary toolbar info.
    let paneView = Preferences.Pane(
        identifier: .privacy,
        title: "Privacy",
        toolbarIcon: NSImage(named: "preferences-privacy")!.fill(color: NSColor.white)
    ) {
        PrivacyView(selectedUpdate: ContentBlockingManager.shared.radBlockPreferences.synchronizeInterval)
    }

    return Preferences.PaneHostingController(pane: paneView)
}

struct PrivacyView: View {
    private let contentWidth: Double = 450.0

    @State var allowListIsPresented: Bool = false
    @State var selectedUpdate: SynchronizeInterval

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(title: "Ads") {
                AdsSection()
            }
            Preferences.Section(title: "Trackers") {
                TrackersSection()
            }
            Preferences.Section(title: "Annoyances") {
                AnnoyancesSection()
            }
            Preferences.Section(title: "Updates Rules") {
                UpdateRulesSection(selectedUpdate: $selectedUpdate)
            }
            Preferences.Section(title: "Allowlist") {
                AllowListSection(allowListIsPresented: $allowListIsPresented)
            }
            Preferences.Section(title: "") {
                VStack(alignment: .leading) {
                    Separator(horizontal: true, hairline: false)
                }
            }
            Preferences.Section(title: "Website Data") {
                WebsiteDataSection()
            }
        }
    }
}

struct PrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyView(selectedUpdate: .daily)
    }
}

struct AdsSection: View {
    var body: some View {
        Checkbox(checkState: ContentBlockingManager.shared.radBlockPreferences.isAdsFilterEnabled, text: "Remove most advertisments while browsing", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            ContentBlockingManager.shared.radBlockPreferences.isAdsFilterEnabled = activated
        }
    }
}

struct TrackersSection: View {
    var body: some View {
        VStack(alignment: .leading) {
            Checkbox(checkState: ContentBlockingManager.shared.radBlockPreferences.isPrivacyFilterEnabled, text: "Prevent Internet history tracking", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                ContentBlockingManager.shared.radBlockPreferences.isPrivacyFilterEnabled = activated
                if !activated && ContentBlockingManager.shared.radBlockPreferences.isSocialMediaFilterEnabled {
                    ContentBlockingManager.shared.radBlockPreferences.isSocialMediaFilterEnabled = false
                }
            }
            Checkbox(checkState: ContentBlockingManager.shared.radBlockPreferences.isSocialMediaFilterEnabled, text: "Block Social Media Buttons", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                ContentBlockingManager.shared.radBlockPreferences.isSocialMediaFilterEnabled = activated
            }
            VStack {
                Text("Websites which embed social media buttons implicitly track your browser history, even if you don’t have an account.")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
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
            Checkbox(checkState: ContentBlockingManager.shared.radBlockPreferences.isAnnoyancesFilterEnabled, text: "Remove banners and popups from websites", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                ContentBlockingManager.shared.radBlockPreferences.isAnnoyancesFilterEnabled = activated
                if !activated && ContentBlockingManager.shared.radBlockPreferences.isCookiesFilterEnabled {
                    ContentBlockingManager.shared.radBlockPreferences.isCookiesFilterEnabled = false
                }
            }
            Checkbox(checkState: ContentBlockingManager.shared.radBlockPreferences.isCookiesFilterEnabled, text: "Hide cookie banners", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                ContentBlockingManager.shared.radBlockPreferences.isCookiesFilterEnabled = activated
            }
            VStack {
                Text("Some websites display banners which impair the site’s functionality in order to force your content to be tracked.")
                    .font(BeamFont.regular(size: 11).swiftUI)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
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
                .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
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
