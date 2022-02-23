//
//  AvailableShortcut.swift
//  Beam
//
//  Created by Remi Santos on 22/02/2022.
//

import Foundation
import BeamCore

extension Shortcut {

    enum AvailableShortcut {
        case goBack
        case goBackEditor
        case goForward
        case goForwardEditor
        case newSearch
        case showAllNotes
        case showJournal
        case toggleNoteWeb
    }
}

extension Shortcut.AvailableShortcut {
    var value: Shortcut {
        switch self {
        case .goBack:
            return Shortcut(modifiers: [.command], keys: [.left])
        case .goBackEditor:
            return Shortcut(modifiers: [.command], keys: [.bracket])
        case .goForward:
            return Shortcut(modifiers: [.command], keys: [.right])
        case .goForwardEditor:
            return Shortcut(modifiers: [.command], keys: [.bracketReversed])
        case .newSearch:
            return Shortcut(modifiers: [.command], keys: [.string("T")])
        case .showAllNotes:
            return Shortcut(modifiers: [.shift, .command], keys: [.string("H")])
        case .showJournal:
            return Shortcut(modifiers: [.shift, .command], keys: [.string("J")])
        case .toggleNoteWeb:
            return Shortcut(modifiers: [.command], keys: [.string("D")])
        }
    }

    private var title: String {
        switch self {
        case .goBack, .goBackEditor:
            return loc("Back")
        case .goForward, .goForwardEditor:
            return loc("Forward")
        case .newSearch:
            return loc("Search")
        case .showAllNotes:
            return loc("All Notes")
        case .showJournal:
            return loc("Journal")
        case .toggleNoteWeb:
            return loc("Note / Web")
        }
    }

    var keysDescription: String {
        value.stringValue
    }

    var description: String {
        "\(title)・\(keysDescription)"
    }
}
