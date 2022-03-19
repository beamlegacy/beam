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
                               shortcut: Shortcut.AvailableShortcut.showJournal.value,
                               handler: { beamState in
                beamState.navigateToJournal(note: nil)
            })
        }

        static var allNotesAction: AutocompleteResult {
            AutocompleteResult(text: loc("All Notes"), source: .action,
                               shortcut: Shortcut.AvailableShortcut.showAllNotes.value,
                               handler: { beamState in
                beamState.navigateToPage(.allNotesWindowPage)
            })
        }

        static var switchToWebAction: AutocompleteResult {
            AutocompleteResult(text: loc("Switch to Web"), source: .action,
                               shortcut: Shortcut.AvailableShortcut.toggleNoteWeb.value,
                               handler: { beamState in
                beamState.toggleBetweenWebAndNote()
            })
        }

        static var switchToNotesAction: AutocompleteResult {
            AutocompleteResult(text: loc("Switch to Notes"), source: .action,
                               shortcut: Shortcut.AvailableShortcut.toggleNoteWeb.value,
                               handler: { beamState in
                beamState.toggleBetweenWebAndNote()
            })
        }

        static var copyTabAddressAction: AutocompleteResult {
            AutocompleteResult(text: loc("Copy Address"), source: .action,
                               customIcon: "editor-url_copy_16",
                               shortcut: Shortcut(modifiers: [.shift, .command], keys: [.string("C")]),
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

        static func createNoteResult(for noteTitle: String?, mode: AutocompleteManager.Mode, asAction: Bool = true, completingText: String? = nil) -> AutocompleteResult {
            let hasNoteTitle = noteTitle?.isEmpty == false
            var shortcut: Shortcut?
            if mode != .noteCreation {
                if !hasNoteTitle && asAction {
                    shortcut = Shortcut(modifiers: [], keys: [.string("@")])
                } else {
                    shortcut = Shortcut(modifiers: [.option], keys: [.enter])
                }
            }
            let icon = AutocompleteResult.Source.createNote.iconName
            let text = hasNoteTitle ? loc("Create Note:") : loc("Create Note...")
            let source: AutocompleteResult.Source = hasNoteTitle || !asAction ? .createNote : .action
            return AutocompleteResult(text: text, source: source, information: noteTitle, customIcon: icon,
                                      shortcut: shortcut, completingText: completingText ?? noteTitle, additionalSearchTerms: ["@", "new"],
                                      handler: hasNoteTitle ? nil : { beamState in
                beamState.autocompleteManager.animateToMode(.noteCreation)
            })
        }
    }

}
