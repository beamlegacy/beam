//
//  SectionFeaturesView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 16/09/2021.
//

import SwiftUI

enum SectionShortcuts: String {
    case browser
    case editor

    var name: String {
        return self.rawValue.capitalized
    }

    var features: [KeyboardFeature] {
        switch self {
        case .browser:
            return [KeyboardFeature(name: "Capture the Web", shortcuts: [Shortcut(modifiers: [.option], keys: [])], prefix: "hold"),
                    KeyboardFeature(name: "Capture page", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("S")]), Shortcut(modifiers: [.option], keys: [.string("S")])], separationString: "or"),
                    KeyboardFeature(name: "Go to Note", shortcuts: [Shortcut.AvailableShortcut.toggleNoteWeb.value]),
                    KeyboardFeature(name: "Omnibox", shortcuts: [Shortcut.AvailableShortcut.newSearch.value,
                                                                 Shortcut(modifiers: [.command], keys: [.string("K")])], separationString: "or"),
                    KeyboardFeature(name: "New Note", shortcuts: [Shortcut.AvailableShortcut.newNote.value]),
                    KeyboardFeature(name: "Close Tab", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("W")])]),
                    KeyboardFeature(name: "Reload page", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("R")])]),
                    KeyboardFeature(name: "Reopen Last Closed Tab", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("Z")]),
                                                                                Shortcut(modifiers: [.shift, .command], keys: [.string("T")])], separationString: "and"),
                    KeyboardFeature(name: "Jump to Previous Tab", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.left]),
                                                                              Shortcut(modifiers: [.shift, .command], keys: [.bracketReversed])], separationString: "or"),
                    KeyboardFeature(name: "Jump to Next Tab", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.right]),
                                                                          Shortcut(modifiers: [.shift, .command], keys: [.bracket])], separationString: "or"),
                    KeyboardFeature(name: "Go back", shortcuts: [Shortcut.AvailableShortcut.goBack.value]),
                    KeyboardFeature(name: "Go forward", shortcuts: [Shortcut.AvailableShortcut.goForward.value]),
                    KeyboardFeature(name: "Zoom in/out", shortcuts: [Shortcut(modifiers: [.command], keys: [.minus]),
                                                                    Shortcut(modifiers: [.command], keys: [.plus])], separationString: "and"),
                    KeyboardFeature(name: "Find", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("F")])])
            ]
        case .editor:
            return [KeyboardFeature(name: "Backlink", shortcuts: [Shortcut(modifiers: [], keys: [.arobase]),
                                                                  Shortcut(modifiers: [], keys: [.doubleBracket])], separationString: "or"),
//                    KeyboardFeature(name: "Block Reference", shortcuts: [Shortcut(modifiers: [], keys: [.string("((")])]),
                    KeyboardFeature(name: "Instant Search", shortcuts: [Shortcut(modifiers: [.command], keys: [.enter])]),
                    KeyboardFeature(name: "Go to Web", shortcuts: [Shortcut.AvailableShortcut.toggleNoteWeb.value]),
                    KeyboardFeature(name: "Indent", shortcuts: [Shortcut(modifiers: [], keys: [.tab])]),
                    KeyboardFeature(name: "Unindent", shortcuts: [Shortcut(modifiers: [.shift], keys: [.tab])]),
                    KeyboardFeature(name: "Fold / Unfold Bullet", shortcuts: [Shortcut(modifiers: [.command], keys: [.up]),
                                                                              Shortcut(modifiers: [.command], keys: [.down])], separationString: "and"),
                    KeyboardFeature(name: "Command Menu", shortcuts: [Shortcut(modifiers: [], keys: [.string("/")])]),
                    KeyboardFeature(name: "Headings 1 & 2", shortcuts: [Shortcut(modifiers: [], keys: [.string("#")]),
                                                                        Shortcut(modifiers: [], keys: [.string("##")])], separationString: "and"),
                    KeyboardFeature(name: "Bold", shortcuts: [Shortcut(modifiers: [], keys: [.string("**")])]),
                    KeyboardFeature(name: "Italic", shortcuts: [Shortcut(modifiers: [], keys: [.string("*")])]),
                    KeyboardFeature(name: "Strikethrough", shortcuts: [Shortcut(modifiers: [], keys: [.string("~~")]), Shortcut(modifiers: [.shift, .command], keys: [.string("E")])], separationString: "or"),
                    KeyboardFeature(name: "Journal", shortcuts: [Shortcut.AvailableShortcut.showJournal.value]),
                    KeyboardFeature(name: "All Notes", shortcuts: [Shortcut.AvailableShortcut.showAllNotes.value]),
                    KeyboardFeature(name: "Find", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("F")])])
            ]        }
    }
}

struct SectionFeaturesView: View {

    let section: SectionShortcuts
    let width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.name)
                .font(BeamFont.regular(size: 15).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .padding(.bottom, 5)
            Separator(horizontal: true)
                .padding(.bottom, 9)
            ForEach(section.features, id: \.self) {
                KeyboardFeatureView(feature: $0, width: width)
            }
        }.if(width != nil) {
            $0.frame(width: width!)
        }
    }
}

struct SectionFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SectionFeaturesView(section: .browser, width: 370)
            SectionFeaturesView(section: .editor, width: 370)
        }
    }
}
