//
//  AboutPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences

let AboutPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .about, title: "About", imageName: "preferences-about") {
    AboutPreferencesView()
}

struct AboutPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                BeamAboutSection()
            }
            Preferences.Section {
                Text("").labelsHidden()
            } content: {
                BeamSocialSection()
            }
        }.frame(height: 352, alignment: .center)
    }
}

struct AboutPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AboutPreferencesView()
    }
}

struct BeamAboutSection: View {
    @Environment(\.openURL) var openURL

    private var TermsAndConditionsButton: some View {
        Button {
            PreferencesManager.openLink(url: URL(string: Configuration.beamTermsConditionsLink))
        } label: {
            (Text("Terms of Service") + Text(Image("editor-url").renderingMode(.template)))
                .underline()
                .font(BeamFont.regular(size: 12).swiftUI)
        }.buttonStyle(PlainButtonStyle())
    }

    private var PrivacyPolicyButton: some View {
        Button {
            PreferencesManager.openLink(url: URL(string: Configuration.beamPrivacyPolicyLink))
        } label: {
            (Text("Privacy Policy") + Text(Image("editor-url").renderingMode(.template)))
                .underline()
                .font(BeamFont.regular(size: 12).swiftUI)
        }.buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer(minLength: 160)
                VStack {
                    Image("preferences-about-beam")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 128, alignment: .top)
                    Spacer()
                }
                GeometryReader { _ in
                    VStack(alignment: .leading) {
                        Text("Beam")
                            .font(BeamFont.medium(size: 20).swiftUI)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(height: 24, alignment: .center)
                        Text("Version \(Information.appVersion ?? "0") (\(Information.appBuild ?? "0"))")
                            .font(BeamFont.medium(size: 10).swiftUI)
                            .foregroundColor(BeamColor.Corduroy.swiftUI)
                            .frame(height: 12, alignment: .center)
                            .padding(.bottom, 2)

                        TermsAndConditionsButton
                            .frame(height: 21)
                        PrivacyPolicyButton
                            .frame(height: 21)
                            .padding(.bottom, 26)

                        Button {
                            PreferencesManager.openLink(url: HelpMenuSection.featureRequest.url)
                        } label: {
                            Text("Feature Request...")
                                .frame(minWidth: 132)
                                .font(BeamFont.regular(size: 13).swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                            .padding(.bottom, 3)
                        Button {
                            PreferencesManager.openLink(url: HelpMenuSection.bugReport.url)
                        } label: {
                            Text("Report a bug...")
                                .frame(minWidth: 110)
                                .font(BeamFont.regular(size: 13).swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                            .padding(.bottom, 5)
                        Button {
                            let email = "help@beamapp.com"
                            let subject = "I have an issue with Beam Version \(Information.appVersion ?? "0") (\(Information.appBuild ?? "0"))"
                            let mailtoStr = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
                            guard let url = URL(string: mailtoStr) else { return }
                            openURL(url)
                        } label: {
                            Text("Contact Support...")
                                .frame(minWidth: 132)
                                .font(BeamFont.regular(size: 13).swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                            .padding(.bottom, 15)
                    }.padding(.top, 16)
                        .padding(.leading, 2)
                }
                Spacer()
            }
        }
    }
}

struct BeamSocialSection: View {
    var body: some View {
        VStack {
            HStack {
                Spacer(minLength: 172)
                VStack(alignment: .leading) {
                    Text("Follow Beam on Twitter")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Text("Get the latest tips and tricks for Beam")
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.Corduroy.swiftUI)
                }
                Spacer()
                Button {
                    PreferencesManager.openLink(url: HelpMenuSection.twitter.url)
                } label: {
                    Text("Follow")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .frame(width: 70)
                }.buttonStyle(BorderedButtonStyle())
                Spacer(minLength: 179)
            }
        }
    }
}
