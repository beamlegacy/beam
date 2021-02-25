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
        updateFormatterView(with: level == 1 ? .h1 : .h2, kind: .heading(level))
    }

    internal func toggleBold() {
        updateFormatterView(with: .bold, attribute: .strong)
    }

    internal func toggleEmphasis() {
        updateFormatterView(with: .italic, attribute: .emphasis)
    }

    internal func toggleUnderline() {
        print("underline")
    }

    internal func toggleStrikeThrough() {
        updateFormatterView(with: .strikethrough, attribute: .strikethrough)
    }

    internal func toggleLink() {
        print("link")
    }

    internal func toggleBiDirectionalLink() {
        guard popover == nil else {
            dismissPopoverOrFormatter()
            return
        }

        showBidirectionalPopover(prefix: 0, suffix: 0)

        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            self.updatePopover()
        }
    }

    internal func toggleUnorderedAndOrderedList() {
        print("UnorderedList // OrderedList")
    }

    internal func toggleQuote() {
        guard let node = focussedWidget as? TextNode else { return }
        updateFormatterView(with: .quote, kind: .quote(1, node.text.text, node.text.text))
    }

    internal func toggleTodo() {
        print("todo")
    }

    internal func toggleCode() {
        print("code")
    }

}
