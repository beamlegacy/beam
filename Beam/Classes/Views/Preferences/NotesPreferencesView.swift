//
//  NotesPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI

extension BeamColor.Cursor: Identifiable {
    var id: Self { self }

    fileprivate  var title: LocalizedStringKey {
        switch self {
        case .whiteBlack:
            return NSApp.effectiveAppearance.isDarkMode ? "White" : "Black"
        default:
            return .init(rawValue.capitalized)
        }
    }
}

private struct CursorColorOption: View {
    let cursor: BeamColor.Cursor

    // cached to avoid computing it again when redrawing
    private let drawingColor: NSColor

    init(cursor: BeamColor.Cursor) {
        self.cursor = cursor
        self.drawingColor = cursor.color.nsColor
    }

    var body: some View {
        HStack {
            Image(nsImage: colorImage)
            Text(cursor.title)
        }
    }

    private var colorImage: NSImage {
        return .init(size: CGSize(width: 24, height: 12), flipped: false, drawingHandler: { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)
            drawingColor.setFill()
            path.fill()
            NSColor(red: .zero, green: .zero, blue: .zero, alpha: 0.1).setStroke()
            path.lineWidth = 0.5
            path.stroke()
            return true
        })
    }
}

struct NotesPreferencesView: View {
    @State private var alwaysShowBullets: Bool = PreferencesManager.alwaysShowBullets
    @State private var cursorColor: BeamColor.Cursor = .current

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row {
                Text("Cursor Color:")
            } content: {
                Picker(selection: $cursorColor, content: {
                    ForEach(BeamColor.Cursor.allCases) { value in
                        CursorColorOption(cursor: value)
                    }
                }, label: {
                    EmptyView()
                })
                .onChange(of: cursorColor) { newValue in
                    // Updating preference cursorColor name (String value)
                    PreferencesManager.cursorColor = newValue.rawValue
                    // Updating color cache since it might expensive to retrieve it
                    BeamColor.Cursor.updateCache(newCursorColor: newValue)
                }
                .pickerStyle(MenuPickerStyle())
                .fixedSize()
                .accessibilityIdentifier("cursor_color")
            }

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
