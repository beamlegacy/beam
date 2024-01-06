//
//  AboutPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI

struct AboutPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row(hasDivider: true) {} content: {
                BeamAboutSection()
            }
            Settings.Row(hasDivider: true) {} content: {
                BeamOpenSourceSection()
            }
            Settings.Row {} content: {
                BeamSocialSection()
            }
        }.frame(alignment: .center)
    }
}

struct AboutPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AboutPreferencesView()
    }
}

private struct BeamAboutSection: View {
    @Environment(\.openURL) var openURL

    private var TermsAndConditionsButton: some View {
        ButtonLabel(customView: { hovered, _ in
            AnyView(
                HStack(spacing: 0) {
                    Text("Terms of Service")
                        .font(BeamFont.regular(size: 12).swiftUI)
                        .underline()
                    Text("↗")
                        .font(BeamFont.regular(size: 11).swiftUI)
                }.foregroundColor(hovered ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
            )
        }, state: .normal, customStyle: .minimalButtonLabel) {
            PreferencesManager.openLink(url: URL(string: Configuration.beamTermsConditionsLink))
        }
    }

    private var PrivacyPolicyButton: some View {
        ButtonLabel(customView: { hovered, _ in
            AnyView(
                HStack(spacing: 0) {
                    Text("Privacy Policy")
                        .font(BeamFont.regular(size: 12).swiftUI)
                        .underline()
                    Text("↗")
                        .font(BeamFont.regular(size: 11).swiftUI)
                }.foregroundColor(hovered ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
            )
        }, state: .normal, customStyle: .minimalButtonLabel) {
            PreferencesManager.openLink(url: URL(string: Configuration.beamPrivacyPolicyLink))
        }
    }

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer(minLength: 160)
                VStack {
                    AppIcon()
                        .scaledToFit()
                        .frame(width: 128, height: 128, alignment: .top)
                    Spacer()
                }
                VStack(alignment: .leading) {
                    Text("Beam")
                        .font(BeamFont.medium(size: 20).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(height: 24, alignment: .center)
                    Text("Version \(Information.appVersion ?? "0") (\(Information.appBuild ?? "0")) \(buildTypeSuffix)")
                        .font(BeamFont.medium(size: 10).swiftUI)
                        .foregroundColor(BeamColor.Corduroy.swiftUI)
                        .frame(height: 12, alignment: .center)
                        .padding(.bottom, 2)

                    TermsAndConditionsButton
                        .frame(height: 21)
                    PrivacyPolicyButton
                        .frame(height: 21)
                        .padding(.bottom, 20)

                    Button {
                        PreferencesManager.openLink(url: HelpMenuSection.featureRequest.url)
                    } label: {
                        Text("Feature Request...")
                            .frame(minWidth: 132)
                            .font(BeamFont.regular(size: 13).swiftUI)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .padding(.bottom, 3)
                    Button {
                        PreferencesManager.openLink(url: HelpMenuSection.bugReport.url)
                    } label: {
                        Text("Report a bug...")
                            .frame(minWidth: 110)
                            .font(BeamFont.regular(size: 13).swiftUI)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 16)
                .padding(.leading, 2)

                Spacer()
            }
        }
    }

    private var buildTypeSuffix: String {
        guard let type = Configuration.branchType, type != .publicRelease else { return "" }
        return "\(type.rawValue)"
    }
}

private struct BeamOpenSourceSection: View {
    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .top) {
                Spacer(minLength: 172)
                VStack(alignment: .leading) {
                    Text("beam is now Open Source!")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Settings.SubtitleLabel("Follow development on GitHub.")
                }
                Spacer()
                Button {
                    PreferencesManager.openLink(url: URL(string: Configuration.beamOpenSourceRepoLink))
                } label: {
                    Text("Open on GitHub")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .frame(width: 110)
                }.buttonStyle(BorderedButtonStyle())
                Spacer(minLength: 179)
            }
        }
    }
}

private struct BeamSocialSection: View {
    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .top) {
                Spacer(minLength: 172)
                VStack(alignment: .leading) {
                    Text("Follow beam on Twitter")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Settings.SubtitleLabel("Get the latest tips and tricks for beam.")
                }
                Spacer()
                Button {
                    PreferencesManager.openLink(url: HelpMenuSection.twitter.url)
                } label: {
                    Text("Follow")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .frame(width: 110)
                }.buttonStyle(BorderedButtonStyle())
                Spacer(minLength: 179)
            }
        }
    }
}

struct AppIcon: View {
    var body: some View {
        if let name = Bundle.main.iconFileName, let nsImage = NSImage(named: name) {
            Image(nsImage: nsImage)
                .resizable()
        } else {
            Image("preferences-about-beam")
                .resizable()
        }
    }
}
