//
//  TextEdit+Shortcut.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 13/01/2021.
//

import Foundation
import Cocoa

extension BeamTextEdit {
    internal func toggleBold() {
        updatePersistentView(with: .strong, .bold)
    }

    internal func toggleEmphasis() {
        updatePersistentView(with: .emphasis, .italic)
    }

    internal func toggleStrikeThrough() {
        updatePersistentView(with: .strikethrough, .strikethrough)
    }
}
