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

    // Enable detection to show popover
    private func enableInputDetector() {
        inputDetectorState += 1
    }

    func buildStringFrom(nodes: [ElementNode]) -> NSAttributedString {
        let strNodes = NSMutableAttributedString()
        for node in nodes {
            guard let node = node as? TextNode else { continue }
            if nodes.count > 1 {
                guard node.text.text.isEmpty else { continue }
                strNodes.append(NSAttributedString(string: String.tabs(max(0, node.element.depth - 1))))
                strNodes.append(node.text.buildAttributedString(fontSize: node.fontSize, cursorPosition: node.cursorPosition, elementKind: node.elementKind, mouseInteraction: nil))
                strNodes.append(NSAttributedString(string: "\n"))
            } else {
                strNodes.append(node.attributedString)
            }
        }

        return strNodes
    }

    // MARK: - Cut
    @IBAction func cut(_ sender: Any) {
        setPasteboard()
        if let nodes = rootNode.state.nodeSelection?.sortedNodes, !nodes.isEmpty {
            let insertEmptyNode = nodes.count == rootNode.element.children.count
            cmdManager.beginGroup(with: "CutElementContent")
            for node in nodes {
                cmdManager.deleteElement(for: node)
            }
            if insertEmptyNode {
                let newElement = BeamElement()
                cmdManager.insertElement(newElement, in: rootNode, after: nil)
            }
            cmdManager.endGroup()
        } else {
            guard let node = rootNode.focusedWidget as? TextNode else { return }
            cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
        }
    }

    // MARK: - Copy
    @IBAction func copy(_ sender: Any) {
        setPasteboard()
    }

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
            let clonedNote: BeamNote = note.deepCopy(withNewId: false, selectedElements: sortedSelectedElements)
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
        if NSPasteboard.general.canReadObject(forClasses: supportedPasteObjects, options: nil) {
            let objects = NSPasteboard.general.readObjects(forClasses: supportedPasteObjects, options: nil)
            if let elementHolder: BeamNoteDataHolder = objects?.first as? BeamNoteDataHolder {
                paste(elementHolder: elementHolder)
            } else if let bTextHolder: BeamTextHolder = objects?.first as? BeamTextHolder {
                guard let node = focusedWidget as? TextNode else { return }
                cmdManager.inputText(bTextHolder.bText, in: node, at: node.cursorPosition)
                scrollToCursorAtLayout = true
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

    private func paste(elementHolder: BeamNoteDataHolder) {
        do {
            cmdManager.beginGroup(with: "PasteElementContent")
            let decodedNote = try JSONDecoder().decode(BeamNote.self, from: elementHolder.noteData)
            for (idx, element) in decodedNote.children.enumerated() {
                let newElement = element.deepCopy(withNewId: true, selectedElements: nil)
                guard let node = focusedWidget as? TextNode,
                      let parent = node.parent as? TextNode else { continue }
                if idx == 0 {
                    cmdManager.insertText(newElement.text, in: node, at: node.elementText.count)
                    cmdManager.focusElement(node, cursorPosition: node.elementText.count)
                    for child in newElement.children {
                        guard let focusNode = focusedWidget as? TextNode else { continue }
                        cmdManager.insertElement(child, in: node, after: focusNode)
                        cmdManager.focus(child, in: focusNode)
                        if let deepestChild = child.deepestChildren() {
                            cmdManager.focus(deepestChild, in: focusNode)
                        }
                    }
                } else {
                    cmdManager.insertElement(newElement, in: parent, after: node)
                    cmdManager.focus(newElement, in: node)
                }
            }
            cmdManager.endGroup()
        } catch {
            Logger.shared.logError("Can't encode Cloned Note", category: .general)
        }
    }

    private func paste(attributedStrings: [NSAttributedString]) {
        cmdManager.beginGroup(with: "PasteAttributedContent")
        guard let node = focusedWidget as? TextNode else { return }
        var lastInserted: ElementNode? = node
        let parent = node.parent as? ElementNode ?? node
        for (idx, attributedString) in attributedStrings.enumerated() {
            guard !attributedString.string.isEmpty else { continue }
            let beamText = BeamText(attributedString)
            if idx == 0 {
                disableInputDetector()
                rootNode.insertText(text: beamText, replacementRange: selectedTextRange)
                enableInputDetector()
            } else {
                let element = BeamElement(beamText)
                cmdManager.insertElement(element, in: parent, after: lastInserted)
                cmdManager.focus(element, in: node)
                lastInserted = focusedWidget as? ElementNode
                scrollToCursorAtLayout = true
            }
        }
        cmdManager.endGroup()
    }
}
