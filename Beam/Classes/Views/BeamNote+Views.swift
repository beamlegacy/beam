//
//  BeamNote+Views.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 28/06/2022.
//

import SwiftUI
import BeamCore

extension BeamNote {

    enum NoteContextualMenuSections {
        case open
        case actions
        case export
    }

    @ViewBuilder static func contextMenu(for noteId: UUID, state: BeamState, sections: Set<NoteContextualMenuSections> = [.open, .actions, .export]) -> some View {
        if let note = fetch(id: noteId) {
            contextualMenu(for: note, state: state, sections: sections)
        }
    }

    @ViewBuilder static func contextualMenu(for note: BeamNote, state: BeamState, sections: Set<NoteContextualMenuSections> = [.open, .actions, .export]) -> some View {
        if sections.contains(.open) {
            Group {
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
            if sections.contains(.actions) || sections.contains(.export) {
                Divider()
            }
        }
        if sections.contains(.actions) {
            let isPinned = state.data.pinnedManager.isPinned(note)
            Button(isPinned ? "Unpin" : "Pin") {
                state.data.pinnedManager.togglePin(note)
            }
            Button(note.publicationStatus.isPublic ? "Unpublish" : "Publish") {
                guard let fileManager = state.data.fileDBManager else { return }
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: !note.publicationStatus.isPublic, fileManager: fileManager) { _ in }
            }
            if sections.contains(.export) {
                Divider()
            }
        }
        if sections.contains(.export) {
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
    }

    /// This function will add in the provided menu the menuItems needed for a BeamNote
    /// - Parameters:
    ///   - menu: The menu to configure
    ///   - note: The note on which the menu will appear
    ///   - state: The current state
    static func showNoteContextualNSMenu(for note: BeamNote, state: BeamState, at position: CGPoint, in view: NSView?, sections: Set<NoteContextualMenuSections> = [.open, .actions, .export]) {

        guard !sections.isEmpty else { return }

        let menu = NSMenu()

        if sections.contains(.open) {
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

            if sections.contains(.actions) || sections.contains(.export) {
                menu.addItem(.separator())
            }
        }

        if sections.contains(.actions) {
            let isPinned = state.data.pinnedManager.isPinned(note)
            menu.addItem(withTitle: isPinned ? loc("Unpin") : loc("Pin")) { _ in
                state.data.pinnedManager.togglePin(note)
            }
            menu.addItem(withTitle: note.publicationStatus.isPublic ? loc("Unpublish") : loc("Publish")) { _ in
                guard let fileManager = state.data.fileDBManager else { return }
                BeamNoteSharingUtils.makeNotePublic(note, becomePublic: !note.publicationStatus.isPublic, fileManager: fileManager) { _ in }
            }

            if sections.contains(.export) {
                menu.addItem(.separator())
            }
        }

        if sections.contains(.export) {
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

        menu.popUp(positioning: nil, at: position, in: view)
    }
}
