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
                    KeyboardFeature(name: "Go to Note", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("D")])]),
                    KeyboardFeature(name: "Omnibox", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("L")])]),
                    KeyboardFeature(name: "New Tab", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("T")])]),
                    KeyboardFeature(name: "Close Tab", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("W")])]),
                    KeyboardFeature(name: "Reload page", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("R")])]),
                    KeyboardFeature(name: "Reopen Last Closed Tab", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("Z")]),
                                                                                Shortcut(modifiers: [.shift, .command], keys: [.string("T")])], separationString: "and"),
                    KeyboardFeature(name: "Jump to Previous Tab", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.left]),
                                                                              Shortcut(modifiers: [.shift, .command], keys: [.bracketReversed])], separationString: "or"),
                    KeyboardFeature(name: "Jump to Next Tab", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.right]),
                                                                          Shortcut(modifiers: [.shift, .command], keys: [.bracket])], separationString: "or"),
                    KeyboardFeature(name: "Go back", shortcuts: [Shortcut(modifiers: [.command], keys: [.left])]),
                    KeyboardFeature(name: "Go forward", shortcuts: [Shortcut(modifiers: [.command], keys: [.right])]),
                    KeyboardFeature(name: "Zoom in/out", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("-")]),
                                                                    Shortcut(modifiers: [.command], keys: [.string("+")])], separationString: "and"),
                    KeyboardFeature(name: "Find", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("F")])])
            ]
        case .editor:
            return [KeyboardFeature(name: "Backlink", shortcuts: [Shortcut(modifiers: [], keys: [.arobase]),
                                                                  Shortcut(modifiers: [], keys: [.doubleBracket])], separationString: "or"),
//                    KeyboardFeature(name: "Block Reference", shortcuts: [Shortcut(modifiers: [], keys: [.string("((")])]),
                    KeyboardFeature(name: "Instant Search", shortcuts: [Shortcut(modifiers: [.command], keys: [.enter])]),
                    KeyboardFeature(name: "Go to Web", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("D")])]),
                    KeyboardFeature(name: "Indent", shortcuts: [Shortcut(modifiers: [], keys: [.tab])]),
                    KeyboardFeature(name: "Unindent", shortcuts: [Shortcut(modifiers: [.shift], keys: [.tab])]),
                    KeyboardFeature(name: "Fold / Unfold Bullet", shortcuts: [Shortcut(modifiers: [.command], keys: [.up]),
                                                                              Shortcut(modifiers: [.command], keys: [.down])], separationString: "and"),
                    KeyboardFeature(name: "Command Menu", shortcuts: [Shortcut(modifiers: [], keys: [.string("/")])]),
                    KeyboardFeature(name: "Headings 1 & 2", shortcuts: [Shortcut(modifiers: [], keys: [.string("#")]),
                                                                        Shortcut(modifiers: [], keys: [.string("##")])], separationString: "and"),
                    KeyboardFeature(name: "Bold", shortcuts: [Shortcut(modifiers: [], keys: [.string("*")])]),
                    KeyboardFeature(name: "Italic", shortcuts: [Shortcut(modifiers: [], keys: [.string("**")])]),
                    KeyboardFeature(name: "Strikeout", shortcuts: [Shortcut(modifiers: [], keys: [.string("~~")])]),
                    KeyboardFeature(name: "Journal", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.string("J")])]),
                    KeyboardFeature(name: "All Notes", shortcuts: [Shortcut(modifiers: [.shift, .command], keys: [.string("H")])]),
                    KeyboardFeature(name: "Find", shortcuts: [Shortcut(modifiers: [.command], keys: [.string("F")])])
            ]        }
    }
}

struct SectionFeaturesView: View {

    let section: SectionShortcuts

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.name)
                .font(BeamFont.regular(size: 15).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .padding(.bottom, 5)
            Separator(horizontal: true)
                .padding(.bottom, 9)
            ForEach(section.features, id: \.self) {
                KeyboardFeatureView(feature: $0)
            }
        }.frame(width: 370)
    }
}

struct SectionFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SectionFeaturesView(section: .browser)
            SectionFeaturesView(section: .editor)
        }
    }
}
