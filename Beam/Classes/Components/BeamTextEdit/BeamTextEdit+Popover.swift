//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa
import BeamCore

extension BeamTextEdit {

    // MARK: - Properties
    private static let queryLimit = 4

    internal func initPopover(mode: PopoverMode, initialText: String?) {
        guard let node = focusedWidget as? TextNode else { return }

        popover = BidirectionalPopover(mode: mode, initialText: initialText)

        guard let popover = popover,
              let view = window?.contentView else { return }

        view.addSubview(popover)

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            switch mode {
            case .internalLink:
                self.validInternalLink(from: node, title)
            default: break
            }
            view.window?.makeFirstResponder(self)
        }

        popover.didSelectItem = { [unowned self] (selectedItem) -> Void in
            switch mode {
            case .blockReference:
                let blockElement = BeamElement("")
                if let item = selectedItem as? PopoverBlockItem {
                    blockElement.kind = .blockReference(item.name, item.id.uuidString)
                    guard let node = focusedWidget as? TextNode,
                          let parent = node.parent as? ElementNode
                    else { return }

                    cmdManager.beginGroup(with: "Insert Block Reference")
                    defer { cmdManager.endGroup() }

                    let startPosition = cursorStartPosition + popoverPrefix
                    let replacementStart = startPosition - popoverPrefix
                    let replacementEnd = rootNode.cursorPosition + popoverSuffix
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
                }
                dismissPopover()
            default: break
            }
            view.window?.makeFirstResponder(self)
        }
    }

    enum Command {
        case none, moveLeft, moveRight, moveUp, moveDown, deleteBackward, deleteForward, insertNewline
    }

    //swiftlint:disable function_body_length cyclomatic_complexity
    internal func updatePopover(with command: Command = .none) {
        guard let node = focusedWidget as? TextNode,
              let popover = popover else { return }

        switch command {
        case .moveUp:
            popover.moveUp()
            return
        case .moveDown:
            popover.moveDown()
            return
        default:
            break
        }

        let cursorPosition = rootNode.cursorPosition

        if command == .deleteForward || command == .moveLeft {
            dismissPopoverOrFormatter()
            return
        }

        if command == .moveRight && ["[[]]", "(())"].contains(node.text.text) {
            cursorStartPosition = 0
            cancelInternalLink()
            dismissPopover()
            return
        }

        if command == .moveRight && cursorPosition == node.text.text.count && popoverSuffix != 0 {
            validInternalLink(from: node, String(node.text.text[cursorStartPosition + popoverPrefix..<cursorPosition - popoverSuffix]))
            return
        }

        let startPosition = cursorStartPosition + popoverPrefix
        if (command == .deleteBackward || command == .deleteForward) &&
            (startPosition > cursorPosition || (popoverPrefix == 0 && cursorPosition == startPosition)) {
            cancelPopover(leaveTextAsIs: true)
            return
        }

        let linkText = String(node.text.text[startPosition..<cursorPosition])
        if linkText.hasPrefix(" ") || linkText.hasSuffix("  ") {
            // escape if the user
            // - type a space right after the start of the popover
            // - typed two consecutive spaces
            cancelPopover(leaveTextAsIs: true)
            return
        }

        let range = startPosition - popoverPrefix ..< cursorPosition + popoverSuffix
        switch popover.mode {
        case .internalLink:
            node.text.setAttributes([.internalLink(linkText)], to: range)
            let items = linkText.isEmpty ?
                documentManager.loadAllWithLimit(BeamTextEdit.queryLimit, [NSSortDescriptor(key: "created_at", ascending: false)]) :
                documentManager.documentsWithLimitTitleMatch(title: linkText, limit: BeamTextEdit.queryLimit)

            popover.items = items.map({ PopoverLinkItem(text: $0.title) })
        case .blockReference:
            let items = linkText.isEmpty ?
                [] :
                GRDBDatabase.shared.search(matchingAnyTokensIn: linkText, maxResults: 5, includeText: true)

            popover.items = items.compactMap {
                guard let uid = UUID(uuidString: $0.uid),
                      let text = $0.text,
                      !text.isEmpty
                else { return nil }
                return PopoverBlockItem(text: text, name: $0.title, id: uid)
            }
        }
        popover.query = linkText

        updatePopoverPosition(with: node)
    }

    internal func cancelPopover(leaveTextAsIs: Bool = false) {
        guard popover != nil,
              let node = focusedWidget as? TextNode else { return }

        dismissPopover()
        let start = cursorStartPosition - popoverPrefix
        let end = rootNode.cursorPosition + popoverSuffix
        if start <= end {
            let range = start..<end
            if leaveTextAsIs {
                node.text.removeAttributes([.internalLink("")], from: range)
            } else {
                node.text.removeSubrange(range)
                rootNode.cursorPosition = range.lowerBound
            }
        }
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        popover?.removeFromSuperview()
        popover = nil
    }

    internal func cancelInternalLink(with text: String? = nil, range: Swift.Range<Int>? = nil) {
        guard let node = focusedWidget as? TextNode,
              popover != nil else { return }

        guard let text = text,
              let range = range else {
            // By default remove internal link from begin to the end
            let text = node.text.text
            node.text.removeAttributes([.internalLink(text)], from: cursorStartPosition..<rootNode.cursorPosition + text.count)
            return
        }

        // Remove internal link at the specific range
        node.text.removeAttributes([.internalLink(text)], from: range)
    }

    private func updatePopoverPosition(with node: TextNode) {
        guard let popover = popover else { return }

        let (xOffset, rect) = node.offsetAndFrameAt(index: cursorStartPosition)
        let offsetGlobal = self.convert(node.offsetInDocument, to: nil)
        let marginTop: CGFloat = rect.maxY == 0 ? 30 : 10
        let yPos = offsetGlobal.y - rect.maxY - popover.idealSize.height - marginTop
        let xPos = offsetGlobal.x + xOffset

        popover.frame = NSRect(x: xPos, y: yPos, width: popover.idealSize.width, height: popover.idealSize.height)

        // Up position when popover is overlapped or clipped by the superview
        if popover.visibleRect.height < popover.idealSize.height {
            popover.frame = NSRect(
                x: xPos,
                y: offsetGlobal.y + 10,
                width: popover.idealSize.width,
                height: popover.idealSize.height
            )
        }
    }

    private func validInternalLink(from node: TextNode, _ title: String) {
        let startPosition = cursorStartPosition + popoverPrefix
        let replacementStart = startPosition - popoverPrefix
        let replacementEnd = rootNode.cursorPosition + popoverSuffix
        // When the cursor is moved to left, the link should be split in 2 (Bi-di + Plain text)
        let linkEnd = rootNode.lastCommand == .moveLeft ?
            replacementStart + rootNode.cursorPosition - popoverPrefix :
            replacementStart + title.count

        node.text.replaceSubrange(replacementStart..<replacementEnd, with: title)

        // Transform no Bi-dir text to plain text
        if rootNode.lastCommand == .moveLeft {
            let splitTitle = node.text.text[linkEnd...]
            cancelInternalLink(with: splitTitle, range: linkEnd..<splitTitle.count + linkEnd)
        }

        node.text.makeInternalLink(replacementStart..<linkEnd)

        rootNode.cursorPosition = linkEnd
        dismissPopover()
    }

}
