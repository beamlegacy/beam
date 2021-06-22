//
//  TextEdit+Hyperlink.swift
//  Beam
//
//  Created by Remi Santos on 23/03/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit: HyperlinkFormatterViewDelegate {
    private static var isExitingLink = false

    // MARK: Public methods

    public func initHyperlinkFormatter() {
        let hyperlinkView = HyperlinkFormatterView(viewType: .inline)
        hyperlinkView.delegate = self
        inlineFormatter = hyperlinkView
    }

    public func showLinkFormatterForSelection(mousePosition: CGPoint = .zero, showMenu: Bool = false) {
        guard let node = focusedWidget as? TextNode else { return }
        var point = mousePosition
        if point == .zero {
            let (_, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
            point = CGPoint(x: rect.midX, y: rect.minY)
        }
        let (_, linkFrame) = node.linkRangeAt(point: point)
        let link = node.linkAt(index: node.cursorPosition)

        showOrHideInlineFormatter(isPresent: false) { [weak self] in
            guard let self = self else { return }
            let linkTitle = self.selectedText
            let targetRange = self.selectedTextRange
            if showMenu {
                var frame = linkFrame
                frame?.origin.x = mousePosition.x
                self.showHyperlinkContextMenu(for: node, targetRange: targetRange, frame: frame, url: link, linkTitle: linkTitle, fromPaste: false)
            } else {
                let frame = linkFrame ?? node.rectAt(caretIndex: node.cursorPosition)
                let url = link ?? URL(string: linkTitle)
                self.showHyperlinkFormatter(for: node, targetRange: targetRange, frame: frame, url: url, linkTitle: linkTitle, debounce: false)
                DispatchQueue.main.async {
                    if let linkEditor = self.inlineFormatter as? HyperlinkFormatterView {
                        linkEditor.startEditingUrl()
                    }
                }
            }
        }
    }

    public func showLinkPasteMenu(for linkRange: BeamText.Range) {
        guard let node = focusedWidget as? TextNode else { return }
        var (_, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
        rect.origin.x = rect.maxX
        guard let link = node.linkAt(index: node.cursorPosition),
              linkCanBeEmbed(link) else { return }
        dismissFormatterView(inlineFormatter)
        let targetRange = linkRange.position..<linkRange.end
        showHyperlinkContextMenu(for: node, targetRange: targetRange, frame: rect, url: link, linkTitle: selectedText, fromPaste: true)
    }

    public func linkStartedHovering(for currentNode: TextNode?, targetRange: Range<Int>, frame: NSRect?, url: URL?, linkTitle: String?) {
        showHyperlinkFormatter(for: currentNode, targetRange: targetRange, frame: frame, url: url, linkTitle: linkTitle)
    }

    public func linkStoppedHovering() {
        dismissHyperlinkView()
    }

    public func linkCanBeEmbed(_ url: URL) -> Bool {
        url.embed != nil
    }

    // MARK: Mouse Events
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        dismissHyperlinkView()
    }

    // MARK: Private methods
    private func dismissHyperlinkView() {
        guard let view = inlineFormatter as? HyperlinkFormatterView else { return }

        let shouldDismiss = !view.hasEditedUrl()
        if shouldDismiss {
            clearDebounceTimer()
            debounceShowHideInlineFormatter(false)
        }
    }

    private func getDefaultItemsForLink(for node: TextNode, link: URL) -> [ContextMenuItem] {
        var allItems = [
            ContextMenuItem(title: "Open Link", action: {
                node.openExternalLink(link: link, element: node.element)
                self.showOrHideInlineFormatter(isPresent: false)
            }),
            ContextMenuItem.separator(),
            ContextMenuItem(title: "Copy Link", action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.absoluteString, forType: .string)
                self.showOrHideInlineFormatter(isPresent: false)
            }),

            ContextMenuItem(title: "Edit Link...", action: {
                self.showOrHideInlineFormatter(isPresent: false) {
                    self.showLinkFormatterForSelection(mousePosition: .zero, showMenu: false)
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        if let linkEditor = self.inlineFormatter as? HyperlinkFormatterView {
                            linkEditor.startEditingUrl()
                        }
                    }
                }
            }),
            ContextMenuItem(title: "Remove Link", action: {
                self.updateLink(in: node, at: self.selectedTextRange, newTitle: nil, newUrl: "", originalUrl: link.absoluteString)
                self.showOrHideInlineFormatter(isPresent: false)
            })
        ]
        if linkCanBeEmbed(link) {
            allItems.insert(ContextMenuItem(title: "Show as Embed", action: {
                self.updateLinkToEmbed(in: node, at: self.selectedTextRange)
                self.showOrHideInlineFormatter(isPresent: false)
            }), at: 3)
        }
        return allItems
    }

    private func getPasteMenuItemsForLink(for node: TextNode, range: Range<Int>) -> [ContextMenuItem] {
        return [
            ContextMenuItem(title: "Show as Link", action: {
                self.showOrHideInlineFormatter(isPresent: false)
            }),
            ContextMenuItem(title: "Show as Embed", action: {
                self.updateLinkToEmbed(in: node, at: range)
                self.showOrHideInlineFormatter(isPresent: false)
            })
        ]
    }

    private func showHyperlinkContextMenu(for targetNode: TextNode?, targetRange: Range<Int>, frame: NSRect?, url: URL?, linkTitle: String?, fromPaste: Bool) {

        guard inlineFormatter?.isMouseInsideView != true else { return }
        clearDebounceTimer()
        guard let frame = frame,
              let node = formatterTargetNode ?? (focusedWidget as? TextNode),
              let link = node.linkAt(index: targetRange.upperBound),
              isInlineFormatterHidden else { return }
        let atPoint = CGPoint(x: frame.origin.x + node.offsetInDocument.x - 10, y: frame.maxY + node.offsetInDocument.y + 7)

        var items: [ContextMenuItem]
        if fromPaste {
            items = self.getPasteMenuItemsForLink(for: node, range: targetRange)
        } else {
            items = self.getDefaultItemsForLink(for: node, link: link)
        }
        let menuView = ContextMenuFormatterView(items: items)
        inlineFormatter = menuView
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: atPoint, from: self, animated: false)

        formatterTargetRange = targetRange
        formatterTargetNode = targetNode
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func showHyperlinkFormatter(for targetNode: TextNode?, targetRange: Range<Int>, frame: NSRect?, url: URL?, linkTitle: String?, debounce: Bool = true) {

        guard inlineFormatter?.isMouseInsideView != true else { return }
        if let currentHyperlinkView = inlineFormatter as? HyperlinkFormatterView {
            if !currentHyperlinkView.hasEditedUrl() && targetRange != formatterTargetRange {
                // another link view is present, dismiss it before the new one
                clearDebounceTimer()
                BeamTextEdit.isExitingLink = true
                debounceShowHideInlineFormatter(false) {
                    BeamTextEdit.isExitingLink = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + FormatterView.disappearAnimationDuration) { [weak self] in
                        guard let self = self else { return }
                        self.showHyperlinkFormatter(for: targetNode, targetRange: targetRange, frame: frame, url: url, linkTitle: linkTitle, debounce: debounce)
                    }
                }
                return
            } else if !BeamTextEdit.isExitingLink {
                return
            }
        }

        clearDebounceTimer()
        initInlineFormatterView(isHyperlinkView: true)

        guard let hyperlinkView = inlineFormatter as? HyperlinkFormatterView,
              let node = targetNode,
              let frame = frame,
              isInlineFormatterHidden else { return }

        formatterTargetRange = targetRange
        formatterTargetNode = targetNode
        hyperlinkView.updateHyperlinkFormatterView(withUrl: url?.absoluteString, title: linkTitle)
        let linkViewSize = hyperlinkView.idealSize
        hyperlinkView.frame.origin.y = frame.minY + node.offsetInDocument.y - linkViewSize.height - 4
        hyperlinkView.frame.origin.x = frame.maxX + node.offsetInDocument.x - linkViewSize.width / 2

        if debounce {
            debounceShowHideInlineFormatter(true)
        } else {
            showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func updateLinkToEmbed(in node: TextNode, at range: Range<Int>) {
        guard let link = node.linkAt(index: range.upperBound) else { return }
        let embedElement = BeamElement()
        embedElement.text = BeamText(text: "")
        embedElement.kind = .embed(link.absoluteString)
        let parent = node.parent as? ElementNode ?? node
        let shouldDeleteEntireNode = node.text.wholeRange == range && node.children.count == 0
        let cmdManager = rootNode.note?.cmdManager
        cmdManager?.beginGroup(with: "Replace Link by Embed")
        cmdManager?.insertElement(embedElement, inNode: parent, afterNode: node)
        if shouldDeleteEntireNode {
            cmdManager?.deleteElement(for: node)
        } else {
            cmdManager?.deleteText(in: node, for: range)
        }
        cmdManager?.endGroup()
    }

    private func updateLink(in node: TextNode, at range: Range<Int>, newTitle: String?, newUrl: String?, originalUrl: String?) {
        guard let noteTitle = node.displayedElementNoteTitle else {
            return
        }
        var attributes = rootNode.state.attributes
        if let link = newUrl ?? originalUrl, !link.isEmpty {
            let (_, validUrl) = link.validUrl()
            attributes = [BeamText.Attribute.link(validUrl)]
        }
        var newCursorPosition = range.upperBound
        if let newTitle = newTitle {
            // edited title & maybe url
            let fallbackTitle = newUrl ?? originalUrl ?? "Link"
            let alwaysATitle = !newTitle.isEmpty ? newTitle : fallbackTitle
            let newBeamText = BeamText(text: alwaysATitle, attributes: attributes)
            let replaceText = ReplaceText(in: node.element.id, of: noteTitle, for: range, with: newBeamText)
            newCursorPosition = range.lowerBound + newBeamText.wholeRange.count + 1
            rootNode.note?.cmdManager.run(command: replaceText, on: rootNode.cmdContext)
        } else if newUrl != nil {
            // edited only url
            if originalUrl != nil {
                // on existing link
                let currentTitle = node.elementText.substring(range: range)
                let newBeamText = BeamText(text: currentTitle, attributes: attributes)
                rootNode.note?.cmdManager.replaceText(in: node, for: range, with: newBeamText)
            } else {
                // on simple text
                rootNode.note?.cmdManager.formatText(in: node, for: nil, with: attributes.first, for: range, isActive: false)
            }
        }
        window?.makeFirstResponder(self)
        rootNode.cancelSelection()
        rootNode.focus(widget: node, position: newCursorPosition)
    }

    // MARK: HyperlinkFormatterView delegate
    internal func hyperlinkFormatterView(_ hyperlinkFormatterView: HyperlinkFormatterView, didFinishEditing newUrl: String?, newTitle: String?, originalUrl: String?) {

        guard let node = formatterTargetNode ?? (focusedWidget as? TextNode) else {
            self.showOrHideInlineFormatter(isPresent: false)
            return
        }

        let editingRange = !node.selectedTextRange.isEmpty ? node.selectedTextRange : self.formatterTargetRange
        if let editingRange = editingRange, !editingRange.isEmpty {
            updateLink(in: node, at: editingRange, newTitle: newTitle, newUrl: newUrl, originalUrl: originalUrl)
        }
        self.showOrHideInlineFormatter(isPresent: false)
    }
}
