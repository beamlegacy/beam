//
//  AutocompleteManager+DefaultActions.swift
//  Beam
//
//  Created by Remi Santos on 15/02/2022.
//

import Foundation
import BeamCore

extension AutocompleteManager {

    enum DefaultActions {
        static var journalAction: AutocompleteResult {
            AutocompleteResult(text: loc("Journal"), source: .action,
                               shortcut: Shortcut(modifiers: [.command, .shift], keys: [.string("D")]),
                               handler: { beamState in
                beamState.navigateToJournal(note: nil)
            })
        }

        static var allNotesAction: AutocompleteResult {
            AutocompleteResult(text: loc("All Notes"), source: .action,
                               shortcut: Shortcut(modifiers: [.command, .shift], keys: [.string("H")]),
                               handler: { beamState in
                beamState.navigateToPage(.allCardsWindowPage)
            })
        }

        static var switchToWebAction: AutocompleteResult {
            AutocompleteResult(text: loc("Switch to Web"), source: .action,
                               shortcut: Shortcut(modifiers: [.command], keys: [.string("D")]),
                               handler: { beamState in
                beamState.toggleBetweenWebAndNote()
            })
        }

        static var switchToNotesAction: AutocompleteResult {
            AutocompleteResult(text: loc("Switch to Notes"), source: .action,
                               shortcut: Shortcut(modifiers: [.command], keys: [.string("D")]),
                               handler: { beamState in
                beamState.toggleBetweenWebAndNote()
            })
        }

        static var copyTabAddressAction: AutocompleteResult {
            AutocompleteResult(text: loc("Copy Address"), source: .action,
                               customIcon: "editor-url_copy_16",
                               shortcut: Shortcut(modifiers: [.command], keys: [.string("C")]),
                               handler: { beamState in
                guard let urlString = beamState.browserTabsManager.currentTab?.url?.absoluteString else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(urlString, forType: .string)
            })
        }

        static var captureTabAction: AutocompleteResult {
            AutocompleteResult(text: loc("Capture Page"), source: .action,
                               customIcon: "collect-page",
                               shortcut: Shortcut(modifiers: [.option], keys: [.string("S")]),
                               handler: { beamState in
                beamState.browserTabsManager.currentTab?.collectTab()
            })
        }

        static func createNoteResult(for text: String) -> AutocompleteResult {
            AutocompleteResult(text: text, source: .createNote, shortcut: Shortcut(modifiers: [.option], keys: [.enter]), completingText: text)
        }
    }

}
