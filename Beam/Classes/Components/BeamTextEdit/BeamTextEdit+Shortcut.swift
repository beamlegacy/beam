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
    // MARK: - Shortcuts IBAction

    @IBAction func toggleHeadingOneAction(_ sender: Any?) {
        cancelPopover()
        toggleHeading(1)
    }

    @IBAction func toggleHeadingTwoAction(_ sender: Any?) {
        cancelPopover()
        toggleHeading(2)
    }

    @IBAction func toggleBoldAction(_ sender: Any?) {
        cancelPopover()
        toggleBold()
    }

    @IBAction func toggleItalicAction(_ sender: Any?) {
        cancelPopover()
        toggleEmphasis()
    }

    @IBAction func toggleUnderlineAction(_ sender: Any?) {
        cancelPopover()
        toggleUnderline()
    }

    @IBAction func toggleStrikethroughAction(_ sender: Any?) {
        cancelPopover()
        toggleStrikeThrough()
    }

    @IBAction func toggleInsertLinkAction(_ sender: Any?) {
        cancelPopover()
        toggleLink()
    }

    @IBAction func toggleBidiLinkAction(_ sender: Any?) {
        cancelPopover()
        toggleBiDirectionalLink()
    }

    @IBAction func toggleListAction(_ sender: Any?) {
        cancelPopover()
        toggleUnorderedAndOrderedList()
    }

    @IBAction func toggleQuoteAction(_ sender: Any?) {
        cancelPopover()
        toggleQuote()
    }

    @IBAction func toggleTodoAction(_ sender: Any?) {
        cancelPopover()
        toggleTodo()
    }

    @IBAction func toggleCodeBlockAction(_ sender: Any?) {
        cancelPopover()
        toggleCode()

    }

    // MARK: - Shortcuts Functional
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
        showLinkFormatterForSelection()
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
        updateFormatterView(with: .checkmark)
    }

    internal func toggleCode() {
        Logger.shared.logDebug("code")
    }

}
