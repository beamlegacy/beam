//
//  BeamTextEdit+SlashMenu.swift
//  Beam
//
//  Created by Remi Santos on 09/06/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    private enum SlashMenuAction {

        // Node formatter
        case h1
        case h2
        case text
        case divider

        // Text Formatters
        case quote
        case bold
        case italic
        case strikethrough
        case internalLink
    }

    public func showSlashFormatter() {
        guard let node = focusedWidget as? TextNode else { return }
        let (_, rect) = node.offsetAndFrameAt(index: node.cursorPosition)
        dismissFormatterView(inlineFormatter)
        var frame = rect
        frame.origin.x = rect.maxX
        if frame.size.height == .zero {
            frame.size.height = node.firstLineHeight
        }
        let targetRange = node.cursorPosition..<node.cursorPosition
        showSlashContextMenu(for: node, targetRange: targetRange, frame: frame)
    }

    private func showSlashContextMenu(for targetNode: TextNode?, targetRange: Range<Int>, frame: NSRect?) {
        guard inlineFormatter?.isMouseInsideView != true else { return }
        clearDebounceTimer()
        guard let frame = frame,
              let node = formatterTargetNode ?? (focusedWidget as? TextNode),
              isInlineFormatterHidden else { return }
        let atPoint = CGPoint(x: frame.origin.x + node.offsetInDocument.x - 10, y: frame.maxY + node.offsetInDocument.y + 7)

        let items = getSlashMenuItems()
        let menuView = ContextMenuFormatterView(items: items, handlesTyping: true)
        inlineFormatter = menuView
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: atPoint, from: self, animated: false)

        formatterTargetRange = targetRange
        formatterTargetNode = targetNode
        DispatchQueue.main.async {
            self.showOrHideInlineFormatter(isPresent: true)
        }
    }

    private func handleAction(_ action: SlashMenuAction) {
        showOrHideInlineFormatter(isPresent: false)
        guard let node = formatterTargetNode,
              let initialRange = formatterTargetRange,
              initialRange.lowerBound <= node.cursorPosition
              else { return }

        node.cmdManager.beginGroup(with: "Slash Menu Formatting")
        let range = initialRange.lowerBound..<node.cursorPosition
        node.cmdManager.deleteText(in: node, for: range)
        var attribute: BeamText.Attribute?
        var elementKind: ElementKind?

        switch action {
        // Basic Text Formats
        case .bold:
            attribute = .strong
        case .italic:
            attribute = .emphasis
        case .strikethrough:
            attribute = .strikethrough
        case .h1:
            elementKind = .heading(1)
        case .h2:
            elementKind = .heading(2)
        case .quote:
            elementKind = .quote(1, node.text.text, node.text.text)
        case .text:
            elementKind = .bullet
            attribute = .none
        case .divider:
            // Divider node coming soon https://linear.app/beamapp/issue/BE-916/menu-divider
            let divider = BeamElement("--------------------")
            let parent = node.parent as? ElementNode ?? node
            node.cmdManager.insertElement(divider, in: parent, after: node)
            let dividerNode = parent.nodeFor(divider)
            let emptyElement = BeamElement("")
            node.cmdManager.insertElement(emptyElement, in: parent, after: dividerNode)
            if let emptyNode = parent.nodeFor(emptyElement) {
                node.cmdManager.focusElement(emptyNode, cursorPosition: 0)
            }
        case .internalLink:
            node.cmdManager.insertText(BeamText(text: "@", attributes: [.internalLink("")]), in: node, at: range.lowerBound)
            node.cmdManager.focusElement(node, cursorPosition: range.lowerBound + 1)
            showBidirectionalPopover(prefix: 1, suffix: 0)
        }
        if attribute != nil || elementKind != nil {
            node.cmdManager.formatText(in: node, for: elementKind, with: attribute, for: initialRange, isActive: false)
        }
        node.cmdManager.endGroup()
    }

    private func getSlashMenuItems() -> [ContextMenuItem] {
        let action: (SlashMenuAction) -> Void = { [weak self] type in
            self?.handleAction(type)
        }
        return [
            ContextMenuItem(title: "Card Reference", subtitle: "@ or [[", icon: "field-card", action: { action(.internalLink) }),
            ContextMenuItem(title: "Quote", subtitle: "\"", icon: "editor-format_quote", action: { action(.quote) }),
            ContextMenuItem.separator(),
            ContextMenuItem(title: "Bold", subtitle: "*", action: { action(.bold) }),
            ContextMenuItem(title: "Italic", subtitle: "**", action: { action(.italic) }),
            ContextMenuItem(title: "Strikethrough", subtitle: "~~", action: { action(.strikethrough) }),
            ContextMenuItem(title: "Heading 1", subtitle: "#", action: { action(.h1) }),
            ContextMenuItem(title: "Heading 2", subtitle: "##", action: { action(.h2) }),
            ContextMenuItem(title: "Text", subtitle: "-", action: { action(.text) }),
            ContextMenuItem(title: "Divider", subtitle: "---", action: { action(.divider) })
        ]
    }
}
