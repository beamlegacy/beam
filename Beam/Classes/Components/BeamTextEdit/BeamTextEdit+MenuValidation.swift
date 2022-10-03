//
//  BeamTextEdit+MenuValidation.swift
//  Beam
//
//  Created by Thomas on 02/09/2022.
//

import Foundation

extension BeamTextEdit: NSMenuItemValidation {
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undo(_:)) {
            func validateCmdManager() -> Bool {
                guard let rootNode = rootNode, rootNode.focusedCmdManager.canUndo else { return false }
                menuItem.title = rootNode.focusedCmdManager.undoMenuItemTitle
                return true
            }
            func validateUndoManager() -> Bool {
                guard let undoManager = window?.firstResponder?.undoManager, undoManager.canUndo else { return false }
                menuItem.title = undoManager.undoMenuItemTitle
                return true
            }

            if window?.firstResponder == self {
                if validateCmdManager() || validateUndoManager() {
                    return true
                }
            } else if validateUndoManager() || validateCmdManager() {
                return true
            }

            menuItem.title = NSLocalizedString("Undo", comment: "Menu Item")
            return false
        }
        if menuItem.action == #selector(redo(_:)) {
            func validateCmdManager() -> Bool {
                guard let rootNode = rootNode, rootNode.focusedCmdManager.canRedo else { return false }
                menuItem.title = rootNode.focusedCmdManager.redoMenuItemTitle
                return true
            }
            func validateUndoManager() -> Bool {
                guard let undoManager = window?.firstResponder?.undoManager, undoManager.canRedo else { return false }
                menuItem.title = undoManager.redoMenuItemTitle
                return true
            }

            if window?.firstResponder == self {
                if validateCmdManager() || validateUndoManager() {
                    return true
                }
            } else if validateUndoManager() || validateCmdManager() {
                return true
            }

            menuItem.title = NSLocalizedString("Redo", comment: "Menu Item")
            return false
        }
        if menuItem.action == #selector(toggleContinuousSpellChecking(_:)) {
            menuItem.state = Persistence.SpellChecking.enable == false ? .off : .on
            return true
        }
        if menuItem.action == #selector(toggleHeadingOneAction(_:)) ||
            menuItem.action == #selector(toggleHeadingTwoAction(_:)) ||
            menuItem.action == #selector(toggleBoldAction(_:)) ||
            menuItem.action == #selector(toggleItalicAction(_:)) ||
            menuItem.action == #selector(toggleUnderlineAction(_:)) ||
            menuItem.action == #selector(toggleStrikethroughAction(_:)) ||
            menuItem.action == #selector(toggleInsertLinkAction(_:)) ||
            menuItem.action == #selector(toggleBidiLinkAction(_:)) ||
            menuItem.action == #selector(toggleListAction(_:)) ||
            menuItem.action == #selector(toggleQuoteAction(_:)) ||
            menuItem.action == #selector(toggleTodoAction(_:)) {
            if let node = focusedWidget as? ElementNode, node.allowFormatting {
                return true
            }
            return false
        }
        if menuItem.action == #selector(toggleCodeBlockAction(_:)) {
            if focusedWidget is CodeNode {
                menuItem.state = .on
                return true
            } else if focusedWidget is TextNode {
                menuItem.state = .off
                return true
            }
            menuItem.state = .off
            return false
        }

        guard menuItem.action == #selector(Self.pasteAsPlainText(_:)) else { return true }
        guard let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteAsPlainTextObjects) else {
            return false
        }
        return !objects.isEmpty
    }
}
