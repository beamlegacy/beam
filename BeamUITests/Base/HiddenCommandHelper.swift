//
//  HiddenCommandHelper.swift
//  Beam
//
//  Created by Remi Santos on 01/09/2022.
//

import Foundation

/// Calls the dynamic identifiers setup by CrossTargetHiddenNotificationsBuilder
class HiddenCommandHelper {

    let beeper: CrossTargetBeeper = CrossTargetNotificationCenterBeeper()

    @discardableResult
    func openTodayNote() -> NoteTestView {
        beeper.beep(identifier: UITestsHiddenMenuAvailableCommands.openTodayNote.rawValue)
        return NoteTestView()
    }

    @discardableResult
    func openNote(title: String) -> NoteTestView {
        beeper.beep(identifier: UITestsHiddenMenuAvailableCommands.openNoteIdentifier(title: title))
        return NoteTestView()
    }
}
