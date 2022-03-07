//
//  MouseCursorManager.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 02/03/2022.
//

import AppKit

/// The goal of MouseCursorManager is to provide a central point for managing mouse cursor in the editor
/// For it to be pertinent, all NSCursor calls from the editor should go through it
final class MouseCursorManager {

    /// Is the mouse cursor currently hidden? True if hidden until next move or explicitely
    var isMouseCursorHidden: Bool {
        return mouseCursorHiddenUntilUnhide || mouseCursorHiddenUntilNextMove
    }

    private var mouseCursorHiddenUntilUnhide = false
    private var mouseCursorHiddenUntilNextMove = false

    /// When cursor is locked, it will not be possible to set a new one until unlocking
    var lockCursor: Bool = false

    /// Will hide the mouse cursor until next mouseMoved event or unhide
    /// - Parameter flag: Should the cursor be hidden
    func hideMouseCursorUntilNextMove(_ flag: Bool) {
        NSCursor.setHiddenUntilMouseMoves(flag)
        mouseCursorHiddenUntilNextMove = flag
    }

    /// Makes the current cursor invisible.
    /// - If another cursor becomes current, that cursor will be invisible, too. It will remain invisible until you invoke the unhide() method.
    /// - Each invocation of hide must be balanced by an invocation of unhide() in order for the cursor to be displayed.
    /// - The hide() method overrides hideMouseCursorUntilNextMove(flag:).
    func hideCursor() {
        guard !mouseCursorHiddenUntilUnhide else { return }
        mouseCursorHiddenUntilUnhide = true
        NSCursor.hide()
    }

    /// Negates an earlier call to hide() by showing the current cursor.
    /// - Each invocation of unhide must be balanced by an invocation of hide() in order for the cursor display to be correct.
    func unhideCursor() {
        guard mouseCursorHiddenUntilUnhide else { return }
        mouseCursorHiddenUntilUnhide = false
        NSCursor.unhide()
    }

    /// Tells that the mouse moved. Will set cursor visible if previously hidden until next move
    func mouseMoved() {
        mouseCursorHiddenUntilNextMove = false
    }

    @discardableResult
    /// Set the current mouse cursor, unless cursor is currently locked
    /// - Parameter cursor: The NSCursor to set as current
    /// - Returns: Was the cursor set (false if cursor is currently locked)
    func setMouseCursor(cursor: NSCursor) -> Bool {
        guard !lockCursor else { return false }
        cursor.set()
        return true
    }
}
