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
            Button("beamNote…") {
                AppDelegate.main.exportOneNoteToBeamNote(note: note)
            }
            Button("Markdown") {
                NSLog("Exporting to Markdown")
            }
        }
        Divider()
        Button("Delete…") {
            note.promptConfirmDelete(for: state)
        }
    }
}
