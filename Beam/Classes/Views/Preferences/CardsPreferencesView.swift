//
//  CardsPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences

let CardsPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .cards, title: "Notes", imageName: "preferences-cards") {
    CardsPreferencesView()
}

struct CardsPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth
    @State private var alwaysShowBullets = PreferencesManager.alwaysShowBullets

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section {
                Text("Spelling & Grammar:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                SpellingGrammarSection()
            }
            Preferences.Section {
                Text("Indentation:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 250, alignment: .trailing)
            } content: {
                Toggle(isOn: $alwaysShowBullets) {
                    Text("Always show bullets")
                }.toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onReceive([alwaysShowBullets].publisher.first()) {
                        PreferencesManager.alwaysShowBullets = $0
                    }
            }
            Preferences.Section {
                Text("Embed Content:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                PreferencesEmbedContentSection()
            }
        }
    }
}

struct CardsPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        CardsPreferencesView()
    }
}

struct SpellingGrammarSection: View {
    @State private var checkSpellingIsOn = PreferencesManager.checkSpellingIsOn
    @State private var checkGrammarIsOn = PreferencesManager.checkGrammarIsOn
    @State private var correctSpellingIsOn = PreferencesManager.correctSpellingIsOn

    var body: some View {
        Toggle(isOn: $checkSpellingIsOn) {
            Text("Check spelling while typing")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([checkSpellingIsOn].publisher.first()) {
                PreferencesManager.checkSpellingIsOn = $0
            }

        Toggle(isOn: $checkGrammarIsOn) {
            Text("Check grammar with spelling")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([checkGrammarIsOn].publisher.first()) {
                PreferencesManager.checkGrammarIsOn = $0
            }

        Toggle(isOn: $correctSpellingIsOn) {
            Text("Correct spelling")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onReceive([correctSpellingIsOn].publisher.first()) {
                PreferencesManager.correctSpellingIsOn = $0
            }
    }
}

struct PreferencesEmbedContentSection: View {
    @State private var embedContent = PreferencesManager.embedContentPreference

    var body: some View {
        Picker("", selection: $embedContent) {
            ForEach(PreferencesEmbedOptions.allCases) { embedContentPref in
                Text(embedContentPref.name)
            }
        }.labelsHidden()
        .frame(width: 212, height: 20)
        .onReceive([self.embedContent].publisher.first()) {
            PreferencesManager.embedContentPreference = $0
        }
    }
}
