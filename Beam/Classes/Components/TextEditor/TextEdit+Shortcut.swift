//
//  TextEdit+Shortcut.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 13/01/2021.
//

import Foundation
import Cocoa

extension BeamTextEdit {
    internal func toggleHeading(_ level: Int) {
        updatePersistentView(with: level == 1 ? .h1 : .h2, kind: .heading(level))
    }

    internal func toggleQuote() {
        guard let node = node as? TextNode else { return }
        updatePersistentView(with: .quote, kind: .quote(1, node.text.text, node.text.text))
    }

    internal func toggleBold() {
        updatePersistentView(with: .bold, attribute: .strong)
    }

    internal func toggleEmphasis() {
        updatePersistentView(with: .italic, attribute: .emphasis)
    }

    internal func toggleStrikeThrough() {
        updatePersistentView(with: .strikethrough, attribute: .strikethrough)
    }
}
