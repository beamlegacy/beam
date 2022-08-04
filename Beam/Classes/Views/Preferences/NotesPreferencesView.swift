//
//  NotesPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI

struct NotesPreferencesView: View {
    @State private var alwaysShowBullets = PreferencesManager.alwaysShowBullets

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Indentation:")
            } content: {
                Toggle(isOn: $alwaysShowBullets) {
                    Text("Always show bullets")
                }.toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onChange(of: alwaysShowBullets, perform: {
                        PreferencesManager.alwaysShowBullets = $0
                    })
            }
        }
    }
}

struct NotesPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NotesPreferencesView()
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
            .onChange(of: checkSpellingIsOn, perform: {
                PreferencesManager.checkSpellingIsOn = $0
            })

        Toggle(isOn: $checkGrammarIsOn) {
            Text("Check grammar with spelling")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: checkGrammarIsOn, perform: {
                PreferencesManager.checkGrammarIsOn = $0
            })

        Toggle(isOn: $correctSpellingIsOn) {
            Text("Correct spelling")
        }.toggleStyle(CheckboxToggleStyle())
            .font(BeamFont.regular(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
            .onChange(of: correctSpellingIsOn, perform: {
                PreferencesManager.correctSpellingIsOn = $0
            })
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
        .onChange(of: embedContent, perform: {
            PreferencesManager.embedContentPreference = $0
        })
    }
}
