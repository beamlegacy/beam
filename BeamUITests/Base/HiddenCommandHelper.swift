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
        NoteTestView().waitForTodayNoteViewToLoad()
        return NoteTestView()
    }

    @discardableResult
    func openNote(title: String) -> NoteTestView {
        beeper.beep(identifier: UITestsHiddenMenuAvailableCommands.openNoteIdentifier(title: title))
        NoteTestView().waitForNoteViewToLoad()
        return NoteTestView()
    }
    
    @discardableResult
    func deleteAllNotes() -> NoteTestView {
        beeper.beep(identifier: UITestsHiddenMenuAvailableCommands.deleteAllNotes.rawValue)
        return NoteTestView()
    }
}

class HiddenNotificationHelper {

    let beeper: CrossTargetBeeper = CrossTargetNotificationCenterBeeper()

    init() { }

    func waitForUserSignIn(timeout: TimeInterval) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        beeper.register(identifier: UITestsHiddenMenuAvailableNotifications.userDidSignIn.rawValue) {
            dispatchGroup.leave()
            self.beeper.unregister(identifier: UITestsHiddenMenuAvailableNotifications.userDidSignIn.rawValue)
        }
        _ = dispatchGroup.wait(timeout: .now() + timeout)
    }
}
