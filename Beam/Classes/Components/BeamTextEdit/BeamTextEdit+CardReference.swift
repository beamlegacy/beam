//
//  BeamTextEdit+CardReference.swift
//  Beam
//
//  Created by Remi Santos on 20/08/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    @discardableResult
    public func makeInternalLinkForSelectionOrShowFormatter(for node: TextNode, applyFormat: Bool = true) -> BeamText.Attribute? {
        let title = node.root?.state.nodeSelection != nil ? node.text.text : selectedText
        guard !title.isEmpty, let doc = documentManager.loadDocumentByTitle(title: title) else {
            showCardReferenceFormatter(initialText: selectedText, atPosition: node.cursorPosition, prefix: 0, suffix: 0)
            return nil
        }
        let attribute = BeamText.Attribute.internalLink(doc.id)
        if applyFormat {
            node.cmdManager.formatText(in: node, for: nil, with: attribute, for: selectedTextRange, isActive: false)
        }
        return attribute
    }

    public func showCardReferenceFormatter(initialText: String? = nil, atPosition: Int, searchCardContent: Bool = false,
                                           prefix: Int = 2, suffix: Int = 2) {
        guard inlineFormatter?.isMouseInsideView != true else { return }
        hideInlineFormatter()
        clearDebounceTimer()
        guard let node = formatterTargetNode ?? (focusedWidget as? TextNode),
              isInlineFormatterHidden else { return }
        var (offset, rect) = node.offsetAndFrameAt(index: atPosition-prefix)
        if rect.size.height == .zero {
            rect.size.height = node.firstLineHeight
        }
        let atPoint = CGPoint(x: offset + node.offsetInDocument.x - 4,
                              y: rect.maxY + node.offsetInDocument.y + 4)
        var targetRange = atPosition..<atPosition
        if let text = initialText {
            targetRange = max(0, targetRange.lowerBound - text.count)..<targetRange.upperBound
        }
        let menuView = CardReferenceFormatterView(initialText: initialText, searchCardContent: searchCardContent, onSelectNoteHandler: { [weak self, weak node] noteId, elementId in
            guard let self = self, let node = node else { return }
            if searchCardContent, let elementId = elementId {
                self.onFinishSelectingBlockRef(in: node, noteId: noteId, elementId: elementId, range: targetRange, prefix: prefix, suffix: suffix)
            } else if let title = BeamNote.fetch(self.documentManager, id: noteId)?.title {
                self.onFinishSelectingLinkRef(in: node, title: title, range: targetRange, prefix: prefix, suffix: suffix)
            }
        }, onCreateNoteHandler: { [weak self] title in
            self?.onFinishSelectingLinkRef(in: node, title: title,
                                           range: targetRange, prefix: prefix, suffix: suffix)
        })
        menuView.typingPrefix = prefix
        menuView.typingSuffix = suffix
        formatterTargetRange = targetRange
        formatterTargetNode = node
        inlineFormatter = menuView
        CustomPopoverPresenter.shared.presentMenu(menuView, atPoint: atPoint, from: self, animated: false)
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func onFinishSelectingLinkRef(in node: TextNode, title: String,
                                          range: Range<Int>, prefix: Int, suffix: Int) {
        hideInlineFormatter()
        let replacementStart = range.lowerBound - prefix
        let replacementEnd = rootNode.cursorPosition + suffix
        let linkEnd = replacementStart + title.count

        node.text.replaceSubrange(replacementStart..<replacementEnd, with: title)

        let (_, linkedNoteId) = node.unproxyElement.makeInternalLink(replacementStart..<linkEnd, createNoteIfNeeded: true)
        if let linkedNoteId = linkedNoteId {
            data?.noteFrecencyScorer.update(id: linkedNoteId, value: 1.0, eventType: .noteBiDiLink, date: BeamDate.now, paramKey: .note30d0)
        }

        rootNode.cursorPosition = linkEnd
    }

    private func onFinishSelectingBlockRef(in node: TextNode, noteId: UUID, elementId: UUID, range: Range<Int>, prefix: Int, suffix: Int) {
        hideInlineFormatter()
        let blockElement = BeamElement("")
        blockElement.kind = .blockReference(noteId, elementId)
        guard let node = focusedWidget as? TextNode,
              let parent = node.parent as? ElementNode
        else { return }

        node.cmdManager.beginGroup(with: "Insert Block Reference")
        defer { node.cmdManager.endGroup() }

        let replacementStart = range.lowerBound - prefix
        let replacementEnd = rootNode.cursorPosition + suffix
        // When the cursor is moved to left, the link should be split in 2 (Bi-di + Plain text)

        node.cmdManager.insertElement(blockElement, inNode: parent, afterNode: node)
        node.cmdManager.deleteText(in: node, for: replacementStart..<replacementEnd)

        let trailingText: BeamText = node.text.suffix(node.text.count - rootNode.cursorPosition)

        if !trailingText.isEmpty {
            node.cmdManager.deleteText(in: node, for: rootNode.cursorPosition..<node.text.count)
            let trailingBlock = BeamElement(trailingText)
            node.cmdManager.insertElement(trailingBlock, inNode: parent, afterElement: blockElement)
        }

        if rootNode.cursorPosition == 0 {
            node.cmdManager.deleteElement(for: node)
        }
        node.cmdManager.focus(blockElement, in: parent)
        if let focusedElement = focusedWidget as? ElementNode {
            node.cmdManager.focusElement(focusedElement, cursorPosition: focusedElement.textCount)
        }
    }

}
