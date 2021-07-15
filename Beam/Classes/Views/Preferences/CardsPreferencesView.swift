//
//  CardsPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences

let CardsPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .cards, title: "Cards", imageName: "preferences-cards") {
    CardsPreferencesView()
}

struct CardsPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth

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
                Text("Embed Content:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            } content: {
                EmbedContentSection()
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
    var body: some View {
        Checkbox(checkState: PreferencesManager.checkSpellingIsOn, text: "Check spelling while typing", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.checkSpellingIsOn = activated
        }
        Checkbox(checkState: PreferencesManager.checkGrammarIsOn, text: "Check grammar with spelling", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.checkGrammarIsOn = activated
        }
        Checkbox(checkState: PreferencesManager.correctSpellingIsOn, text: "Correct spelling", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
            PreferencesManager.correctSpellingIsOn = activated
        }
    }
}

struct EmbedContentSection: View {
    @State private var embedContent = PreferencesManager.embedContentPreference

    var body: some View {
        Picker("", selection: $embedContent) {
            ForEach(EmbedContent.allCases) { embedContentPref in
                Text(embedContentPref.name)
            }
        }.labelsHidden()
        .frame(width: 212, height: 20)
        .onReceive([self.embedContent].publisher.first()) { value in
            PreferencesManager.embedContentPreference = value
        }
    }
}
