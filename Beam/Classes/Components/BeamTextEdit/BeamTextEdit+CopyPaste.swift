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

    func buildStringFrom(nodes: [TextNode]) -> NSAttributedString {
        let strNodes = NSMutableAttributedString()
        for node in nodes {
            if nodes.count > 1 {
                guard !node.text.text.isEmpty else { continue }
                strNodes.append(NSAttributedString(string: String.tabs(node.element.depth - 1)))
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
            rootNode.note?.cmdManager.beginGroup(with: "CutElementContent")
            for node in nodes {
                rootNode.cmdManager.deleteElement(for: node)
            }
            if insertEmptyNode {
                guard let noteTitle = rootNode.note?.title else { return }
                let insertEmptyNode = InsertEmptyNode(with: rootNode.element.id, of: noteTitle, at: 0)
                rootNode.note?.cmdManager.run(command: insertEmptyNode, on: rootNode.cmdContext)
            }
            rootNode.note?.cmdManager.endGroup()
        } else {
            guard let node = rootNode.focusedWidget as? TextNode else { return }
            rootNode.cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
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
                rootNode.note?.cmdManager.inputText(bTextHolder.bText, in: node, at: node.cursorPosition)
                scrollToCursorAtLayout = true
            } else if let attributedStr = objects?.first as? NSAttributedString {
                paste(attributedStrings: attributedStr.split(seperateBy: "\n"))
            } else if let pastedStr: String = objects?.first as? String {
                paste(str: pastedStr)
            }
        }
    }

    private func paste(elementHolder: BeamNoteDataHolder) {
        do {
            rootNode.note?.cmdManager.beginGroup(with: "PasteElementContent")
            let decodedNote = try JSONDecoder().decode(BeamNote.self, from: elementHolder.noteData)
            for element in decodedNote.children.reversed() {
                let newElement = element.deepCopy(withNewId: true, selectedElements: nil)
                guard let node = focusedWidget as? TextNode,
                      let parent = node.parent as? TextNode else { continue }
                rootNode.note?.cmdManager.insertElement(newElement, in: parent, after: node)
            }
            rootNode.note?.cmdManager.endGroup()
        } catch {
            Logger.shared.logError("Can't encode Cloned Note", category: .general)
        }
    }

    private func paste(attributedStrings: [NSAttributedString]) {
        rootNode.note?.cmdManager.beginGroup(with: "PasteAttributedContent")
        for (idx, attributedString) in attributedStrings.enumerated() {
            let str = String(attributedString.string)
            if idx == 0 {
                disableInputDetector()
                insertText(string: str, replacementRange: selectedTextRange)
                enableInputDetector()
            } else {
                guard let node = focusedWidget as? TextNode else { continue }
                rootNode.note?.cmdManager.insertElement(BeamElement(), in: node, after: nil)
                guard let newNode = focusedWidget as? TextNode else { continue }
                let bText = BeamText(text: str, attributes: [])
                rootNode.note?.cmdManager.inputText(bText, in: newNode, at: 0)
                scrollToCursorAtLayout = true
            }
            guard let node = focusedWidget as? TextNode,
                  let ranges = node.text.text.urlRangesInside(),
                  let noteTitle = node.root?.note?.title else { return }
            ranges.compactMap { Range($0) }.forEach { range in
                let linkStr = String(str[range.lowerBound..<range.upperBound])
                let formatText = FormattingText(in: node.element.id, of: noteTitle, for: nil, with: .link(linkStr), for: range, isActive: false)
                rootNode.note?.cmdManager.run(command: formatText, on: rootNode.cmdContext)
            }

            let boldRanges = attributedString.getRangesOfFont(for: .bold)
            for boldRange in boldRanges {
                let boldText = FormattingText(in: node.element.id, of: noteTitle, for: nil, with: .strong, for: Range(boldRange), isActive: false)
                rootNode.note?.cmdManager.run(command: boldText, on: rootNode.cmdContext)
            }
            let emphasisRanges = attributedString.getRangesOfFont(for: .italic)
            for emphasisRange in emphasisRanges {
                let emphasisText = FormattingText(in: node.element.id, of: noteTitle, for: nil, with: .emphasis, for: Range(emphasisRange), isActive: false)
                rootNode.note?.cmdManager.run(command: emphasisText, on: rootNode.cmdContext)
            }

            let linkRanges = attributedString.getLinks()
            for linkRange in linkRanges {
                let linkText = FormattingText(in: node.element.id, of: noteTitle, for: nil, with: .link(linkRange.key), for: Range(linkRange.value), isActive: false)
                rootNode.note?.cmdManager.run(command: linkText, on: rootNode.cmdContext)
            }
        }
        rootNode.note?.cmdManager.endGroup()
    }

    private func paste(str: String) {
        let lines = str.split(whereSeparator: \.isNewline)
        rootNode.note?.cmdManager.beginGroup(with: "PasteStringContent")
        for (idx, line) in lines.enumerated() {
            let str = String(line)
            if idx == 0 {
                disableInputDetector()
                insertText(string: str, replacementRange: selectedTextRange)
                enableInputDetector()
            } else {
                guard let node = focusedWidget as? TextNode else { continue }
                rootNode.note?.cmdManager.insertElement(BeamElement(), in: node, after: nil)
                guard let newNode = focusedWidget as? TextNode else { continue }
                let bText = BeamText(text: str, attributes: [])
                rootNode.note?.cmdManager.inputText(bText, in: newNode, at: 0)
                scrollToCursorAtLayout = true
            }
            guard let node = focusedWidget as? TextNode,
                  let ranges = node.text.text.urlRangesInside(),
                  let noteTitle = node.root?.note?.title else { return }
            ranges.compactMap { Range($0) }.forEach { range in
                let linkStr = String(str[range.lowerBound..<range.upperBound])
                let formatText = FormattingText(in: node.element.id, of: noteTitle, for: nil, with: .link(linkStr), for: range, isActive: false)
                rootNode.note?.cmdManager.run(command: formatText, on: rootNode.cmdContext)
            }
        }
        rootNode.note?.cmdManager.endGroup()
    }
}
