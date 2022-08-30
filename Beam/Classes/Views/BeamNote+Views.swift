//
//  BeamNote+Views.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 28/06/2022.
//

import SwiftUI
import BeamCore

extension BeamNote {

    @ViewBuilder static func contextMenu(for noteId: UUID, state: BeamState) -> some View {
        if let note = fetch(id: noteId) {
            contextualMenu(for: note, state: state)
        }
    }

    @ViewBuilder static func contextualMenu(for note: BeamNote, state: BeamState) -> some View {
        Group {
            Button("Open Note") {
                state.navigateToNote(id: note.id)
            }
            Button("Open in New Window") {
                state.openNoteInNewWindow(id: note.id)
            }
            if Configuration.branchType == .develop {
                Button("Open in Side Window") {
                    state.openNoteInMiniEditor(id: note.id)
                }
                Button("Open in Split View") {
                    state.sideNote = note
                }
            }
        }
        Divider()
        let isPinned = state.data.pinnedManager.isPinned(note)
        Button(isPinned ? "Unpin" : "Pin") {
            state.data.pinnedManager.togglePin(note)
        }
        Button(note.publicationStatus.isPublic ? "Unpublish" : "Publish") {
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: !note.publicationStatus.isPublic) { _ in }
        }
        Divider()
        Menu("Export") {
            Button("Beam Note…") {
                AppDelegate.main.exportOneNoteToBeamNote(note: note)
            }
            Button("Markdown…") {
                AppDelegate.main.exportNotesToMarkdown([note])
            }
        }
        Divider()
        Button("Delete…") {
            note.promptConfirmDelete(for: state)
        }
    }

    /// This function will add in the provided menu the menuItems needed for a BeamNote
    /// - Parameters:
    ///   - menu: The menu to configure
    ///   - note: The note on which the menu will appear
    ///   - state: The current state
    func configureNoteContextualMenu(_ menu: NSMenu, for note: BeamNote, state: BeamState) {

        menu.addItem(withTitle: loc("Open Note")) { _ in
            state.navigateToNote(id: note.id)
        }

        menu.addItem(withTitle: loc("Open in New Window")) { _ in
            state.openNoteInNewWindow(id: note.id)
        }

        if Configuration.branchType == .develop {
            menu.addItem(withTitle: loc("Open in Side Window")) { _ in
                state.openNoteInMiniEditor(id: note.id)
            }
            menu.addItem(withTitle: loc("Open in Split View")) { _ in
                state.sideNote = note
            }
        }

        menu.addItem(.separator())

        let isPinned = state.data.pinnedManager.isPinned(note)
        menu.addItem(withTitle: isPinned ? loc("Unpin") : loc("Pin")) { _ in
            state.data.pinnedManager.togglePin(note)
        }
        menu.addItem(withTitle: note.publicationStatus.isPublic ? loc("Unpublish") : loc("Publish")) { _ in
            BeamNoteSharingUtils.makeNotePublic(note, becomePublic: !note.publicationStatus.isPublic) { _ in }
        }

        menu.addItem(.separator())

        let export = menu.addItem(withTitle: loc("Export")) { _ in }
        let exportMenu = NSMenu()
        exportMenu.addItem(withTitle: loc("Beam Note…")) { _ in
            AppDelegate.main.exportOneNoteToBeamNote(note: note)
        }
        exportMenu.addItem(withTitle: loc("Markdown…")) { _ in
            AppDelegate.main.exportNotesToMarkdown([note])
        }
        menu.setSubmenu(exportMenu, for: export)
    }
}
