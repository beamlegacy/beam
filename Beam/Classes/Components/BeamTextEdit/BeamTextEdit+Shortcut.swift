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
        hideInlineFormatter()
        toggleHeading(1)
    }

    @IBAction func toggleHeadingTwoAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleHeading(2)
    }

    @IBAction func toggleBoldAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleBold()
    }

    @IBAction func toggleItalicAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleEmphasis()
    }

    @IBAction func toggleUnderlineAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleUnderline()
    }

    @IBAction func toggleStrikethroughAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleStrikeThrough()
    }

    @IBAction func toggleInsertLinkAction(_ sender: Any?) {
        toggleLink()
    }

    @IBAction func toggleBidiLinkAction(_ sender: Any?) {
        toggleBiDirectionalLink()
    }

    @IBAction func toggleListAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleUnorderedAndOrderedList()
    }

    @IBAction func toggleQuoteAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleQuote()
    }

    @IBAction func toggleTodoAction(_ sender: Any?) {
        hideInlineFormatter()
        toggleTodo()
    }

    @IBAction func toggleCodeBlockAction(_ sender: Any?) {
        hideInlineFormatter()
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
        guard let node = focusedWidget as? TextNode else { return }
        makeInternalLinkForSelectionOrShowFormatter(for: node)
    }

    internal func toggleUnorderedAndOrderedList() {
        Logger.shared.logDebug("UnorderedList // OrderedList")
    }

    internal func toggleQuote() {
        guard let node = focusedWidget as? TextNode else { return }
        updateFormatterView(with: .quote, kind: .quote(1, origin: SourceMetadata(string: node.text.text, title: node.text.text)))
    }

    internal func toggleTodo() {
        updateFormatterView(with: .checkmark)
    }

    internal func toggleCode() {
        Logger.shared.logDebug("code")
    }
}
