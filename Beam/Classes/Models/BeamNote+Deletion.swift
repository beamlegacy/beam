//
//  BeamNote+Deletion.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/05/2022.
//

import AppKit
import BeamCore

extension BeamNote {
    func promptConfirmDelete(state: BeamState, undoManager: UndoManager?) {
        guard let window = AppDelegate.main.window else { return }

        let alert = NSAlert()
        alert.messageText = loc("Are you sure you want to delete the note \"\(title)\"?", comment: "Alert Message")
        alert.addButton(withTitle: loc("Delete", comment: "Alert Button"))
        alert.addButton(withTitle: loc("Cancel", comment: "Alert Button"))
        alert.alertStyle = .warning

        alert.beginSheetModal(for: window) { [self] response in
            guard response == .alertFirstButtonReturn else { return }
            Self.confirmedDelete(id, state: state, undoManager: undoManager)
        }
    }

    static private func confirmedDelete(_ noteID: BeamNote.ID, state: BeamState, undoManager: UndoManager?) {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }

        let navigateBack = (state.mode == .note) && (state.currentNote?.id == noteID)

        if navigateBack {
            preDeletionNavigation(state: state)
        }

        let cmdManager = CommandManagerAsync<BeamDocumentCollection>()
        cmdManager.deleteDocuments(ids: [noteID], in: collection) { [self] _ in
            if let undoManager = undoManager {
                registerUndo(noteID,
                             state: state,
                             cmdManager: cmdManager,
                             undoManager: undoManager,
                             undoNavigation: navigateBack)
            }
        }
    }

    static private func registerUndo(_ noteID: BeamNote.ID,
                                     state: BeamState,
                                     redo: Bool = false,
                                     cmdManager: CommandManagerAsync<BeamDocumentCollection>,
                                     undoManager: UndoManager,
                                     undoNavigation: Bool) {
        guard let collection = state.data.currentDocumentCollection else { return }

        undoManager.registerUndo(withTarget: state, handler: { state in
            let navigateBack: Bool
            if redo {
                navigateBack = (state.mode == .note) && (state.currentNote?.id == noteID)
            } else {
                navigateBack = false
            }

            self.registerUndo(noteID,
                              state: state,
                              redo: !redo,
                              cmdManager: cmdManager,
                              undoManager: undoManager,
                              undoNavigation: navigateBack)
            if redo {
                if navigateBack {
                    self.preDeletionNavigation(state: state)
                }
                cmdManager.redoAsync(context: collection, completion: { _ in })
            } else {
                cmdManager.undoAsync(context: collection, completion: { success in
                    if success && undoNavigation {
                        state.navigateToNote(id: noteID)
                    }
                })
            }
        })

        undoManager.setActionName("Delete Note")
    }

    static private func preDeletionNavigation(state: BeamState) {
        // To prevent complex interactions with the state and notifications it receives, let's apply the state changes before we delete the note:
        if state.canGoBackForward.back {
            state.goBack()
        } else {
            state.navigateToJournal(note: nil)
        }
        state.backForwardList.clearForward()
        state.updateCanGoBackForward()
    }
}
