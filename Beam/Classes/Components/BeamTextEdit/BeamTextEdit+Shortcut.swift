//
//  TextEdit+Shortcut.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 13/01/2021.
//

import Foundation
import Cocoa
import BeamCore

extension BeamTextEdit {
    internal func toggleHeading(_ level: Int) {
        updateFormatterView(with: level == 1 ? .h1 : .h2, kind: .heading(level))
    }

    internal func toggleBold() {
        updateFormatterView(with: .bold, attribute: .strong)
    }

    internal func toggleEmphasis() {
        updateFormatterView(with: .italic, attribute: .emphasis)
    }

    internal func toggleUnderline() {
        updateFormatterView(with: .underline, attribute: .underline)
    }

    internal func toggleStrikeThrough() {
        updateFormatterView(with: .strikethrough, attribute: .strikethrough)
    }

    internal func toggleLink() {
        Logger.shared.logDebug("link")
    }

    internal func toggleBiDirectionalLink() {
        guard popover == nil else {
            dismissPopoverOrFormatter()
            return
        }
        hideInlineFormatter()
        showBidirectionalPopover(mode: .internalLink, prefix: 0, suffix: 0)
    }

    internal func toggleUnorderedAndOrderedList() {
        Logger.shared.logDebug("UnorderedList // OrderedList")
    }

    internal func toggleQuote() {
        guard let node = focusedWidget as? TextNode else { return }
        updateFormatterView(with: .quote, kind: .quote(1, node.text.text, node.text.text))
    }

    internal func toggleTodo() {
        Logger.shared.logDebug("todo")
    }

    internal func toggleCode() {
        Logger.shared.logDebug("code")
    }

}
