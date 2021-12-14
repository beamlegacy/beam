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
        guard let rootNode = rootNode else { return nil }
        let title = node.root?.state.nodeSelection != nil ? node.text.text : selectedText
        guard !title.isEmpty, let doc = documentManager.loadDocumentByTitle(title: title) else {
            let text = selectedText
            let pos = selectedTextRange.lowerBound
            let previousSelectedRange = selectedTextRange
            let cmdManager = rootNode.focusedCmdManager
            cmdManager.beginGroup(with: "Prepare Internal Link Search")
            cmdManager.cancelSelection(node)
            cmdManager.focusElement(node, cursorPosition: previousSelectedRange.upperBound)
            cmdManager.formatText(in: node, for: nil, with: Self.formatterAutocompletingAttribute, for: previousSelectedRange, isActive: false)
            cmdManager.endGroup()
            showCardReferenceFormatter(initialText: text, atPosition: pos, prefix: 0, suffix: 0)
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
        var atPoint = baseInlineFormatterPosition(for: node, cursorPosition: atPosition)
        atPoint.x -= 4
        atPoint.y += 8
        var targetRange = atPosition..<atPosition
        if let text = initialText {
            targetRange = targetRange.lowerBound..<(targetRange.upperBound + text.count)
        }
        let menuView = CardReferenceFormatterView(initialText: initialText, searchCardContent: searchCardContent,
                                                  typingPrefix: prefix, typingSuffix: suffix, excludingElements: [node.elementId],
                                                  onSelectNoteHandler: { [weak self, weak node] noteId, elementId in
            guard let self = self, let node = node else { return }
            if searchCardContent, let elementId = elementId {
                self.onFinishSelectingBlockRef(in: node, noteId: noteId, elementId: elementId, range: targetRange, prefix: prefix, suffix: suffix)
            } else if let title = BeamNote.fetch(id: noteId)?.title {
                self.onFinishSelectingLinkRef(in: node, title: title, range: targetRange, prefix: prefix, suffix: suffix)
            }
        }, onCreateNoteHandler: { [weak self] title in
            self?.onFinishSelectingLinkRef(in: node, title: title,
                                           range: targetRange, prefix: prefix, suffix: suffix)
        })
        formatterTargetRange = targetRange
        formatterTargetNode = node
        inlineFormatter = menuView
        prepareInlineFormatterWindowBeforeShowing(menuView, atPoint: atPoint)
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func onFinishSelectingLinkRef(in node: TextNode, title: String,
                                          range: Range<Int>, prefix: Int, suffix: Int) {
        guard let rootNode = rootNode else { return }
        hideInlineFormatter()
        let replacementStart = range.lowerBound - prefix
        let replacementEnd = rootNode.cursorPosition + suffix
        let linkEnd = replacementStart + title.count
        let cmdManager = rootNode.focusedCmdManager
        cmdManager.beginGroup(with: "Card Link Insert")
        defer { cmdManager.endGroup() }
        cmdManager.replaceText(in: node, for: replacementStart..<replacementEnd, with: BeamText(text: title, attributes: []))

        let (_, linkedNoteId) = node.unproxyElement.makeInternalLink(replacementStart..<linkEnd)
        if let linkedNoteId = linkedNoteId {
            data?.noteFrecencyScorer.update(id: linkedNoteId, value: 1.0, eventType: .noteBiDiLink, date: BeamDate.now, paramKey: .note30d0)
            data?.noteFrecencyScorer.update(id: linkedNoteId, value: 1.0, eventType: .noteBiDiLink, date: BeamDate.now, paramKey: .note30d1)
        }
        cmdManager.insertText(BeamText(text: " "), in: node, at: linkEnd)
        rootNode.cursorPosition = linkEnd + 1
    }

    private func onFinishSelectingBlockRef(in node: TextNode, noteId: UUID, elementId: UUID, range: Range<Int>, prefix: Int, suffix: Int) {
        guard let rootNode = rootNode else { return }
        hideInlineFormatter()
        let blockElement = BeamElement("")
        blockElement.kind = .blockReference(noteId, elementId)
        guard let node = focusedWidget as? TextNode,
              let parent = node.parent as? ElementNode
        else { return }

        let cmdManager = rootNode.focusedCmdManager
        cmdManager.beginGroup(with: "Block Reference Insert")
        defer { node.cmdManager.endGroup() }

        let replacementStart = range.lowerBound - prefix
        let replacementEnd = rootNode.cursorPosition + suffix
        // When the cursor is moved to left, the link should be split in 2 (Bi-di + Plain text)

        cmdManager.insertElement(blockElement, inNode: parent, afterNode: node)
        cmdManager.deleteText(in: node, for: replacementStart..<replacementEnd)

        let trailingText: BeamText = node.text.suffix(node.text.count - rootNode.cursorPosition)

        if !trailingText.isEmpty {
            cmdManager.deleteText(in: node, for: rootNode.cursorPosition..<node.text.count)
            let trailingBlock = BeamElement(trailingText)
            cmdManager.insertElement(trailingBlock, inNode: parent, afterElement: blockElement)
        }

        if rootNode.cursorPosition == 0 {
            cmdManager.deleteElement(for: node)
        }
        cmdManager.focus(blockElement, in: parent)
        if let focusedElement = focusedWidget as? ElementNode {
            cmdManager.focusElement(focusedElement, cursorPosition: focusedElement.textCount)
        }
    }

}
