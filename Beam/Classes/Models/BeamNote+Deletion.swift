//
//  BeamNote+Deletion.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/05/2022.
//

import AppKit
import BeamCore

extension BeamNote {
    private func confirmedDelete(for state: BeamState) {
        guard let collection = BeamData.shared.currentDocumentCollection else { return }
        // To prevent complex interactions with the state and notifications it receives, let's apply the state changes before we delete the note:
        if state.canGoBackForward.back {
            state.goBack()
        } else {
            state.navigateToJournal(note: nil)
        }
        state.backForwardList.clearForward()
        state.updateCanGoBackForward()

        let cmdManager = CommandManagerAsync<BeamDocumentCollection>()
        cmdManager.deleteDocuments(ids: [self.id], in: collection)
    }

    func promptConfirmDelete(for state: BeamState) {
        guard let note = note else { return }
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete the note \"\(note.title)\"?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = AppDelegate.main.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self = self else { return }
            self.confirmedDelete(for: state)
        }
    }
}
