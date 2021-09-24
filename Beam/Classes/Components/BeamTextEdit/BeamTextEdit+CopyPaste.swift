//
//  BeamTextEdit+CopyPaste.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/04/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    // Disable detection during copy / paste
    private func disableInputDetector() {
        inputDetectorState -= 1
    }

    // Enable detection
    private func enableInputDetector() {
        inputDetectorState += 1
    }

    func buildStringFrom(image source: UUID) -> NSAttributedString {
        guard let imageRecord = try? BeamFileDBManager.shared.fetch(uid: source)
        else {
            Logger.shared.logError("ImageNode unable to fetch image '\(source)' from FileDB", category: .noteEditor)
            return NSAttributedString()
        }

        guard let image = NSImage(data: imageRecord.data)
        else {
            Logger.shared.logError("ImageNode unable to decode image '\(source)' from FileDB", category: .noteEditor)
            return NSAttributedString()
        }

        let attachmentCell: NSTextAttachmentCell = NSTextAttachmentCell(imageCell: image)
        let attachment: NSTextAttachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        let attrString: NSAttributedString = NSAttributedString(attachment: attachment)
        return attrString

    }

    func buildStringFrom(node: ElementNode) -> NSAttributedString {
        let strNode = NSMutableAttributedString()
        strNode.append(NSAttributedString(string: String.tabs(max(0, node.element.depth - 1)) + String.bullet() + String.spaces(1)))

        switch node.elementKind {
        case .bullet, .heading, .quote, .check, .blockReference, .code:
            let config = BeamTextAttributedStringBuilder.Config(elementKind: node.elementKind,
                                                                ranges: node.elementText.ranges,
                                                                fontSize: TextNode.fontSizeFor(kind: node.elementKind),
                                                                caret: nil,
                                                                markedRange: .none,
                                                                selectedRange: .none,
                                                                mouseInteraction: nil)
            let builder = BeamTextAttributedStringBuilder()
            strNode.append(builder.build(config: config))

        case .divider:
            strNode.append(NSAttributedString(string: "\n---\n"))

        case let .image(source):
            strNode.append(buildStringFrom(image: source))

        case let .embed(source):
            guard let url = URL(string: source) else { return strNode }
            strNode.append(NSAttributedString(string: source, attributes: [.link: url]))
        }

        return strNode
    }

    func buildStringFrom(nodes: [ElementNode]) -> NSAttributedString {
        let strNodes = NSMutableAttributedString()
        for node in nodes {
            guard (node as? TextRoot) == nil else { continue }
            if nodes.count > 1 {
                strNodes.append(buildStringFrom(node: node))
                strNodes.append(NSAttributedString(string: "\n"))
            } else {
                strNodes.append(buildStringFrom(node: node))
            }
        }

        return strNodes
    }

    // MARK: - Cut
    @IBAction func cut(_ sender: Any) {
        setPasteboard()
        if let nodes = rootNode.state.nodeSelection?.sortedNodes, !nodes.isEmpty {
            rootNode.eraseNodeSelection(createEmptyNodeInPlace: nodes.count == rootNode.element.children.count)
        } else {
            guard let node = rootNode.focusedWidget as? TextNode else { return }
            node.cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
        }
    }

    // MARK: - Copy
    @IBAction func copy(_ sender: Any) {
        setPasteboard()
    }

    // swiftlint:disable:next function_body_length
    private func setPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes(supportedCopyTypes, owner: nil)
        let strNodes = NSMutableAttributedString()
        var beamText: BeamText?
        var noteData: Data?

        if  let note = rootNode.note,
            let sortedNodes = rootNode.state.nodeSelection?.sortedNodes, !sortedNodes.isEmpty {
            var sortedSelectedElements: [BeamElement] = []
            sortedNodes.forEach { (node) in
                sortedSelectedElements.append(node.element)
            }
            guard let clonedNote: BeamNote = note.deepCopy(withNewId: false, selectedElements: sortedSelectedElements, includeFoldedChildren: true) else {
                Logger.shared.logError("Copy error, unable to copy \(note)", category: .noteEditor)
                return
            }
            do {
                noteData = try JSONEncoder().encode(clonedNote)
            } catch {
                Logger.shared.logError("Can't encode Cloned Note", category: .general)
            }
            strNodes.append(buildStringFrom(nodes: sortedNodes))
        } else {
            if let node = focusedWidget as? TextNode {
                let range = NSRange(location: selectedTextRange.lowerBound, length: selectedTextRange.count)
                let attributedString = node.attributedString.attributedSubstring(from: range)
                strNodes.append(attributedString)
                if let range = Range(range) {
                    beamText = node.element.text.extract(range: range)
                }
            }
        }

        do {
            if let noteData = noteData {
                let elementHolder = BeamNoteDataHolder(noteData: noteData)
                let elementHolderData = try PropertyListEncoder().encode(elementHolder)
                pasteboard.setData(elementHolderData, forType: .noteDataHolder)
            }
            if let bText = beamText {
                let bTextHolder = BeamTextHolder(bText: bText)
                let beamTextData = try PropertyListEncoder().encode(bTextHolder)
                pasteboard.setData(beamTextData, forType: .bTextHolder)
            }
            // Added this to clean lineSpacing, while lineSpacing in TextNode is not working
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 0
            strNodes.addAttribute(.paragraphStyle, value: style, range: strNodes.wholeRange)
            let docAttrRtf: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: NSAttributedString.DocumentType.rtf, .characterEncoding: String.Encoding.utf8]
            let rtfData = try strNodes.data(from: NSRange(location: 0, length: strNodes.length), documentAttributes: docAttrRtf)
            pasteboard.setData(rtfData, forType: .rtf)
            pasteboard.setString(strNodes.string, forType: .string)
        } catch {
            Logger.shared.logError("Error creating RTF from Attributed String", category: .general)
        }
    }

    // MARK: - Paste
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    @IBAction func paste(_ sender: Any) {
        disableAnimationAtNextLayout()
        if NSPasteboard.general.canReadObject(forClasses: supportedPasteObjects, options: nil) {
            let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteObjects, options: nil)
            if let elementHolder: BeamNoteDataHolder = objects?.first as? BeamNoteDataHolder {
                paste(elementHolder: elementHolder)
            } else if let bTextHolder: BeamTextHolder = objects?.first as? BeamTextHolder {
                paste(beamTextHolder: bTextHolder)
            } else if let attributedStr = objects?.first as? NSAttributedString {
                paste(attributedStrings: attributedStr.split(seperateBy: "\n"))
            } else if let pastedStr: String = objects?.first as? String {
                var lines = [NSAttributedString]()
                pastedStr.enumerateLines { line, _ in
                    lines.append(NSAttributedString(string: line))
                }
                paste(attributedStrings: lines)
            }
        }
    }
    private func paste(beamTextHolder: BeamTextHolder) {
        rootNode.insertText(text: beamTextHolder.bText, replacementRange: nil)
        addNoteSourceFrom(text: beamTextHolder.bText)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func paste(elementHolder: BeamNoteDataHolder) {
        do {
            guard let mngrNode = focusedWidget else {
                Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
                return
            }
            mngrNode.cmdManager.beginGroup(with: "PasteElementContent")
            defer { mngrNode.cmdManager.endGroup() }

            if rootNode.state.nodeSelection != nil {
                rootNode.eraseNodeSelection(createEmptyNodeInPlace: true, createNodeInEmptyParent: false)
            } else if !rootNode.state.selectedTextRange.isEmpty {
                guard let node = focusedWidget as? TextNode else { return }
                node.cmdManager.deleteText(in: node, for: rootNode.rangeToDeleteText(in: node, cursorAt: rootNode.cursorPosition, forward: false))
            }
            guard let firstNode = focusedWidget as? TextNode else { return }
            let previousBullet = firstNode.element

            guard let node = focusedWidget as? ElementNode,
                  let parent = node.parent as? ElementNode else {
                Logger.shared.logError("Can't paste on a node that is not an element node", category: .noteEditor)
                return
            }

            let decodedNote = try JSONDecoder().decode(BeamNote.self, from: elementHolder.noteData)
            for element in decodedNote.children {
                guard let newElement = element.deepCopy(withNewId: true, selectedElements: nil, includeFoldedChildren: true) else {
                    Logger.shared.logError("Paste error, unable to copy \(element)", category: .noteEditor)
                    return
                }
                guard let node = focusedWidget as? ElementNode else {
                    return
                }
                node.cmdManager.insertElement(newElement, inNode: parent, afterElement: node.element)
                node.cmdManager.focus(newElement, in: node)
                addNoteSourceFrom(text: element.text)
            }
            if previousBullet.children.isEmpty, previousBullet.text.isEmpty {
                node.cmdManager.deleteElement(for: previousBullet)
            }
        } catch {
            Logger.shared.logError("Can't encode Cloned Note", category: .general)
        }
    }

    private func paste(attributedStrings: [NSAttributedString]) {
        guard let mngrNode = focusedWidget else {
            Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
            return
        }
        mngrNode.cmdManager.beginGroup(with: "PasteAttributedContent")
        guard let node = focusedWidget as? TextNode else { return }
        var lastInserted: ElementNode? = node
        let parent = node.parent as? ElementNode ?? node
        for (idx, attributedString) in attributedStrings.enumerated() {
            guard !attributedString.string.isEmpty else { continue }
            let cleanedText = attributedString.clean(with: "\\s\u{2022}\\s", in: NSRange(0..<3))
            let beamText = BeamText(attributedString: cleanedText)
            if idx == 0 {
                disableInputDetector()
                rootNode.insertText(text: beamText, replacementRange: selectedTextRange)
                enableInputDetector()
            } else {
                let element = BeamElement(beamText)
                parent.cmdManager.insertElement(element, inNode: parent, afterNode: lastInserted)
                parent.cmdManager.focus(element, in: node)
                lastInserted = focusedWidget as? ElementNode
            }
            addNoteSourceFrom(text: beamText)
        }

        if let lastInsertedNode = lastInserted as? TextNode,
           let linkRanges = lastInserted?.elementText.linkRanges, linkRanges.count == 1,
           let linkRange = linkRanges.first {

            let embedable = showLinkEmbedPasteMenu(for: linkRange)
            if !embedable {
                mngrNode.cmdManager.insertText(BeamText(text: " ", attributes: []), in: lastInsertedNode, at: linkRange.end)
                mngrNode.cmdManager.focusElement(lastInsertedNode, cursorPosition: linkRange.end + 1)
            }
        }
        mngrNode.cmdManager.endGroup()
    }
}
