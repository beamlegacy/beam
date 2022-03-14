//
//  BeamTextEdit+CopyPaste.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/04/2021.
//

import Foundation
import BeamCore
import UniformTypeIdentifiers

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
                                                                fontColor: node.color,
                                                                caret: nil,
                                                                markedRange: .none,
                                                                selectedRange: .none,
                                                                searchedRanges: [],
                                                                mouseInteraction: nil)
            let builder = BeamTextAttributedStringBuilder()
            strNode.append(builder.build(config: config))

        case .divider:
            strNode.append(NSAttributedString(string: "\n---\n"))

        case let .image(id, _, _):
            strNode.append(buildStringFrom(image: id))

        case .embed(let url, let source, _):
            strNode.append(NSAttributedString(string: source?.title ?? url.absoluteString, attributes: [.link: url]))
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
        guard let rootNode = rootNode else { return }
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
        guard let rootNode = rootNode else { return }
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
            if let noteData = noteData, !noteData.isEmpty {
                let elementHolder = BeamNoteDataHolder(noteData: noteData)
                let elementHolderData = try PropertyListEncoder().encode(elementHolder)
                pasteboard.addTypes([.noteDataHolder], owner: nil)
                pasteboard.setData(elementHolderData, forType: .noteDataHolder)
            }
            if let bText = beamText, !bText.isEmpty {
                let bTextHolder = BeamTextHolder(bText: bText)
                let beamTextData = try PropertyListEncoder().encode(bTextHolder)
                pasteboard.addTypes([.bTextHolder], owner: nil)
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
            } else if let image = objects?.first as? NSImage {
                paste(image: image)
            } else if let fileUrl = objects?.first as? NSURL {
                paste(url: fileUrl as URL)
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
        rootNode?.insertText(text: beamTextHolder.bText, replacementRange: nil)
        addNoteSourceFrom(text: beamTextHolder.bText)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func paste(elementHolder: BeamNoteDataHolder) {
        guard let rootNode = rootNode else { return }
        do {
            guard let mngrNode = focusedWidget else {
                Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
                return
            }
            let cmdManager = mngrNode.cmdManager
            cmdManager.beginGroup(with: "PasteElementContent")
            defer { cmdManager.endGroup() }

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

            let decodedNote = try BeamJSONDecoder().decode(BeamNote.self, from: elementHolder.noteData)
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

    private func paste(url: URL) {
        guard let type = UTType(tag: url.pathExtension.lowercased(), tagClass: .filenameExtension, conformingTo: nil),
              type.isSubtype(of: .image),
              let image = NSImage(contentsOf: url) else {
            Logger.shared.logError("Unable to load image from url \(url)", category: .noteEditor)
            return
        }

        paste(image: image, with: url.lastPathComponent)
    }

    private func paste(image: NSImage, with name: String? = nil) {
        guard let node = focusedWidget as? ElementNode,
              let parent = node.parent as? ElementNode else {
            Logger.shared.logError("Can't paste on a node that is not an element node", category: .noteEditor)
            return
        }

        let jpegImageData = image.jpegRepresentation

        let fileManager = BeamFileDBManager.shared
        do {
            let cmdManager = node.cmdManager
            cmdManager.beginGroup(with: "PasteImageContent")
            defer { cmdManager.endGroup() }

            if rootNode?.state.nodeSelection != nil {
                rootNode?.eraseNodeSelection(createEmptyNodeInPlace: false, createNodeInEmptyParent: false)
            }

            let uid = try fileManager.insert(name: name ?? "image\(UUID())", data: jpegImageData)
            let newElement = BeamElement()
            newElement.kind = .image(uid, displayInfos: MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width), displayRatio: nil))
            cmdManager.insertElement(newElement, inNode: parent, afterNode: node)
            if node.element.kind.isText && node.elementText.isEmpty {
                cmdManager.deleteElement(for: node)
            }
            try fileManager.addReference(fromNote: note.id, element: newElement.id, to: uid)
            cmdManager.focus(newElement, in: parent, leading: false)
            Logger.shared.logInfo("Added Image to note \(String(describing: note)) with uid \(uid) from pasted file (\(image))", category: .noteEditor)
        } catch {
            Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
        }
    }

    private func paste(attributedStrings: [NSAttributedString]) {
        guard let rootNode = rootNode else { return }
        guard let mngrNode = focusedWidget else {
            Logger.shared.logError("Cannot paste contents in an editor without a focused bullet", category: .noteEditor)
            return
        }
        let cmdManager = mngrNode.cmdManager
        cmdManager.beginGroup(with: "PasteAttributedContent")
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
                cmdManager.insertText(BeamText(text: " ", attributes: []), in: lastInsertedNode, at: linkRange.end)
                cmdManager.focusElement(lastInsertedNode, cursorPosition: linkRange.end + 1)
            }
        }
        cmdManager.endGroup()
    }
}
