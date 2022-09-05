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
            if let undoManager = window?.firstResponder?.undoManager, undoManager.canUndo {
                menuItem.title = undoManager.undoMenuItemTitle
                return true
            }
            if let cmdManager = rootNode?.focusedCmdManager, cmdManager.canUndo {
                menuItem.title = cmdManager.undoMenuItemTitle
                return true
            }
            menuItem.title = NSLocalizedString("Undo", comment: "Menu Item")
            return false
        }
        if menuItem.action == #selector(redo(_:)) {
            if let undoManager = window?.firstResponder?.undoManager, undoManager.canRedo {
                menuItem.title = undoManager.redoMenuItemTitle
                return true
            }
            if let cmdManager = rootNode?.focusedCmdManager, cmdManager.canRedo {
                menuItem.title = cmdManager.redoMenuItemTitle
                return true
            }
            menuItem.title = NSLocalizedString("Redo", comment: "Menu Item")
            return false
        }

        guard menuItem.action == #selector(Self.pasteAsPlainText(_:)) else { return true }
        guard let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteAsPlainTextObjects) else {
            return false
        }
        return !objects.isEmpty
    }
}
