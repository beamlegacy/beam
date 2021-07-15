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

    @State var beamVersion: String = "1.0"
    @State var beamBuildNumber: String = "104"
    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                BeamAboutSection(beamVersion: $beamVersion,
                                 beamBuildNumber: $beamBuildNumber)
            }
            Preferences.Section {
                Text("").labelsHidden()
            } content: {
                BeamSocialSection()
            }
        }
    }
}

struct AboutPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        AboutPreferencesView()
    }
}

struct BeamAboutSection: View {
    @Binding var beamVersion: String
    @Binding var beamBuildNumber: String
    var body: some View {
        VStack {
            HStack {
                Image("preferences-about-beam")
                VStack(alignment: .leading) {
                    Text("Beam")
                        .font(BeamFont.medium(size: 20).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Text("Version \(beamVersion) (\(beamBuildNumber))")
                        .font(BeamFont.medium(size: 10).swiftUI)
                        .foregroundColor(BeamColor.Corduroy.swiftUI)
                        .frame(height: 12, alignment: .center)
                    Text("Terms & Conditions")
                        .underline()
                        .font(BeamFont.medium(size: 12).swiftUI)
                        .foregroundColor(BeamColor.Corduroy.swiftUI)
                        .frame(height: 21, alignment: .center)
                    Text("Privacy Policy")
                        .underline()
                        .font(BeamFont.medium(size: 12).swiftUI)
                        .foregroundColor(BeamColor.Corduroy.swiftUI)
                        .frame(height: 21, alignment: .center)
                    HStack {
                        Button {

                        } label: {
                            Text("Bug Report")
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                        Button {

                        } label: {
                            Text("Feature Request")
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                    }
                }
            }
        }.frame(width: 573, alignment: .center)
    }
}

struct BeamSocialSection: View {
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Spacer()
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

                } label: {
                    Text("Follow")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 70, height: 20, alignment: .center)
                }.buttonStyle(BorderedButtonStyle())
            }
        }.frame(width: 573, alignment: .center)
    }
}
