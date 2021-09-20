//
//  BeamTextEdit+InputDetector.swift
//  Beam
//
//  Created by Remi Santos on 18/06/2021.
//

import Foundation
import BeamCore

extension BeamTextEdit {

    private func inputDetectorGetPositionAndPrecedingChar(in node: TextNode) -> (Int, String) {
        let pos = self.selectedTextRange.isEmpty ? rootNode.cursorPosition : self.selectedTextRange.lowerBound
        let substr = node.text.extract(range: max(0, pos - 1) ..< pos)
        let left = substr.text
        return (pos, left)
    }

    private func insertPair(node: TextNode, _ left: String, _ right: String) {
        let cmdManager = rootNode.focusedCmdManager
        let selectedRange = selectedTextRange
        cmdManager.beginGroup(with: "Insert Pair")
        cmdManager.insertText(BeamText(text: right), in: node, at: selectedRange.upperBound)
        cmdManager.insertText(BeamText(text: left), in: node, at: selectedRange.lowerBound)
        cmdManager.focusElement(node, cursorPosition: rootNode.cursorPosition + 1)
        cmdManager.setSelection(node, selectedRange.lowerBound + 1 ..< selectedRange.upperBound + 1)
        cmdManager.endGroup()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func preDetectInput(_ input: String) -> Bool {
        guard inputDetectorEnabled else { return true }
        guard let node = focusedWidget as? TextNode else { return true }
        defer { inputDetectorLastInput = input }

        let handlers: [String: () -> Bool] = [
            "@": { [unowned self] in
                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                guard left == " " || pos == 0 else { return true }
                self.showCardReferenceFormatter(atPosition: pos + 1, searchCardContent: false, prefix: 1, suffix: 0)
                return true
            },
            "[": { [unowned self] in
                let cmdManager = rootNode.focusedCmdManager
                let pos = self.selectedTextRange.isEmpty ? rootNode.cursorPosition : self.selectedTextRange.lowerBound
                let substr = node.text.extract(range: max(0, pos - 1) ..< pos)
                let left = substr.text // capture the left of the cursor to check for an existing [

                if pos > 0 && left == "[" {
                    if !self.selectedTextRange.isEmpty {
                        if makeInternalLinkForSelectionOrShowFormatter(for: node) != nil {
                            cmdManager.beginGroup(with: "Internal Link Clear")
                            let selectedRangeBefore = selectedTextRange
                            cmdManager.deleteText(in: node, for: pos-1..<pos)
                            cmdManager.deleteText(in: node, for: selectedRangeBefore.upperBound-1..<selectedRangeBefore.upperBound)
                            hideInlineFormatter()
                            cmdManager.focusElement(node, cursorPosition: self.selectedTextRange.upperBound-1)
                            cmdManager.cancelSelection(node)
                            cmdManager.endGroup()
                        } else {
                            insertPair(node: node, "[", "]")
                        }
                        return false
                    } else {
                        cmdManager.beginGroup(with: "Internal Link Prepare")
                        cmdManager.insertText(BeamText(text: "]"), in: node, at: pos)
                        cmdManager.formatText(in: node, for: nil, with: Self.formatterAutocompletingAttribute, for: pos-2..<pos+2, isActive: false)
                        cmdManager.endGroup()
                        showCardReferenceFormatter(atPosition: pos + 1)
                        return true
                    }
                } else if pos == 0 || left != "-" {
                    insertPair(node: node, "[", "]")
                    return false
                }
                return true
            },
            "]": { [unowned self] in
                guard node.text.count >= 2 else { return true }
                let cmdManager = rootNode.focusedCmdManager
                let startRange = 0..<2
                let substr = node.text.extract(range: startRange)
                if substr.text == "-[" {
                    cmdManager.deleteText(in: node, for: startRange)
                    cmdManager.formatText(in: node, for: .check(false), with: nil, for: nil, isActive: false)
                    return false
                }
                return true
            },
            "(": { [unowned self] in
                return preInputHandleParenthesis(node: node)
            },
            "{": { [unowned self] in
                insertPair(node: node, "{", "}")
                return false
            },
            "\"": { [unowned self] in
                insertPair(node: node, "\"", "\"")
                return false
            },
            "/": { [unowned self] in
                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                guard left == " " || pos == 0 else { return true }
                self.showSlashFormatter()
                return true
            },
            " ": { [unowned self] in
                return preInputHandleSpace(node: node)
            }
        ]

        if let handler = handlers[inputDetectorLastInput + input] {
            return handler()
        } else if let handler = handlers[input] {
            return handler()
        }

        return true
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func postDetectInput(_ input: String) -> BeamText.Attribute? {
        guard inputDetectorEnabled else { return nil }
        guard let node = focusedWidget as? TextNode else { return nil }

        let makeQuote = { [unowned self] () -> BeamText.Attribute? in
            let level1 = node.text.prefix(2).text == "> "
            let level2 = node.text.prefix(3).text == ">> "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level > 0 {
                Logger.shared.logInfo("Make quote", category: .ui)

                node.cmdManager.deleteText(in: node, for: 0..<level + 1)
                node.cmdManager.formatText(in: node, for: .quote(level, "", ""), with: nil, for: nil, isActive: false)
                self.rootNode.cursorPosition = 0
            }
            return nil
        }

        let makeBoldOrItalic = { [unowned self] () -> BeamText.Attribute? in
            let isBold = node.text.prefix(2).text == "* "
            let isItalic = node.text.prefix(3).text == "** "

            if node.cursorPosition <= 2, isBold {
                Logger.shared.logInfo("Make Bold", category: .ui)
                self.rootNode.cursorPosition = 0
                node.cmdManager.deleteText(in: node, for: 0..<2)

                if !node.text.isEmpty {
                    node.cmdManager.formatText(in: node, for: nil, with: .strong, for: node.text.wholeRange, isActive: false)
                    return nil
                }
                return .strong
            }

            if node.cursorPosition <= 3, isItalic {
                Logger.shared.logInfo("Make Italic", category: .ui)
                self.rootNode.cursorPosition = 0
                node.cmdManager.deleteText(in: node, for: 0..<3)

                if !node.text.isEmpty {
                    node.cmdManager.formatText(in: node, for: nil, with: .emphasis, for: node.text.wholeRange, isActive: false)
                    return nil
                }
                return .emphasis
            }
            return nil
        }

        let makeStrikethrough = { [unowned self] () -> BeamText.Attribute? in
            let isStrikethrough = node.text.prefix(3).text == "~~ "
            if node.cursorPosition <= 3, isStrikethrough {
                Logger.shared.logInfo("Make Strikethrough", category: .ui)
                self.rootNode.cursorPosition = 0
                node.cmdManager.deleteText(in: node, for: 0..<3)

                if !node.text.isEmpty {
                    node.cmdManager.formatText(in: node, for: nil, with: .strikethrough, for: node.text.wholeRange, isActive: false)
                    return nil
                }
                return .strikethrough
            }
            return nil
        }

        let makeUnderline = { [unowned self] () -> BeamText.Attribute? in
            let isUnderline = node.text.prefix(2).text == "_ "
            if node.cursorPosition <= 2, isUnderline {
                Logger.shared.logInfo("Make Underline", category: .ui)
                self.rootNode.cursorPosition = 0
                node.cmdManager.deleteText(in: node, for: 0..<2)

                if !node.text.isEmpty {
                    node.cmdManager.formatText(in: node, for: nil, with: .underline, for: node.text.wholeRange, isActive: false)
                    return nil
                }
                return .underline
            }
            return nil
        }

        let makeHeader = { [unowned self] () -> BeamText.Attribute? in
            let level1 = node.text.prefix(2).text == "# "
            let level2 = node.text.prefix(3).text == "## "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level != 0 {
                Logger.shared.logInfo("Make header", category: .ui)

                // In this case we will reparent all following sibblings that are not a header to the current node as Paper does
                guard self.focusedWidget?.isEmpty ?? false else { return nil }
                guard let node = self.focusedWidget as? TextNode else { return nil }
                let element = node.element
                guard let parentNode = self.focusedWidget?.parent as? TextNode else { return nil }
                let parent = parentNode.element
                guard let index = self.focusedWidget?.indexInParent else { return nil }
                for sibbling in parent.children.suffix(from: index + 1) {
                    guard !sibbling.isHeader else { return nil }
                    element.addChild(sibbling)
                }
                node.cmdManager.deleteText(in: node, for: 0..<level + 1)
                node.cmdManager.formatText(in: node, for: .heading(level), with: nil, for: nil, isActive: false)
                self.rootNode.cursorPosition = 0
                return nil
            }
            return nil
        }

        let handlers: [String: () -> BeamText.Attribute?] = [
            "#": makeHeader,
            ">": makeQuote,
            "*": makeBoldOrItalic,
            "~": makeStrikethrough,
            "_": makeUnderline,
            " ": {
                if let res = makeHeader() {
                    return res
                } else if let res = makeQuote() {
                    return res
                } else if let res = makeBoldOrItalic() {
                    return res
                } else if let res = makeStrikethrough() {
                    return res
                } else if let res = makeUnderline() {
                    return res
                }
                return nil
            }
        ]

        if let handler = handlers[input] {
            return handler()
        } else if let handler = handlers[inputDetectorLastInput + input] {
            return handler()
        }
        return nil
    }

    // MARK: - Handlers
    // MARK: "space"
    private func preInputHandleSpace(node: TextNode) -> Bool {
        guard self.selectedTextRange.isEmpty else { return true }

        let (pos, _) = inputDetectorGetPositionAndPrecedingChar(in: node)
        if let (linkString, range) = linkStringForPrecedingCharacters(atIndex: pos, in: node) {
            let cmdManager = rootNode.focusedCmdManager
            cmdManager.insertText(BeamText(text: " "), in: node, at: range.upperBound)
            cmdManager.beginGroup(with: "Automatically format typed link")
            cmdManager.formatText(in: node, for: nil, with: .link(linkString), for: range, isActive: false)
            cmdManager.focusElement(node, cursorPosition: range.upperBound + 1)
            cmdManager.endGroup()
            return false
        }
        return true
    }

    func linkStringForPrecedingCharacters(atIndex index: Int, in node: TextNode) -> (String, Range<Int>)? {
        if let precedingWordIndex = node.text.text.indexForCharactersGroup(before: index), precedingWordIndex < index {
            let wordRange = precedingWordIndex..<index
            let precedingText = node.text.extract(range: wordRange)
            let precedingTextString = precedingText.text
            // Automatic Link Detection
            if precedingText.links.isEmpty && (precedingTextString.mayBeURL || precedingTextString.mayBeEmail) {
                let (isValid, validUrlString) = precedingTextString.validUrl()
                return isValid ? (validUrlString, wordRange) : nil
            }
        }
        return nil
    }

    // MARK: "("
    private func preInputHandleParenthesis(node: TextNode) -> Bool {
        let cmdManager = rootNode.focusedCmdManager
        let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
        // capture the left of the cursor to check for an existing (
        if pos > 0 && left == "(" {
            let initialText = selectedText
            var ignoreInput = true
            var atPosition = pos
            if !self.selectedTextRange.isEmpty {
                insertPair(node: node, "(", ")")
                cmdManager.beginGroup(with: "Block Ref Prepare")
                let newPosition = selectedTextRange.upperBound
                cmdManager.focusElement(node, cursorPosition: newPosition)
                cmdManager.cancelSelection(node)
                atPosition = newPosition
            } else {
                cmdManager.beginGroup(with: "Block Ref Prepare")
                ignoreInput = false
                cmdManager.insertText(BeamText(text: ")"), in: node, at: pos)
                atPosition = pos + 1
            }
            cmdManager.endGroup()
            self.showCardReferenceFormatter(initialText: initialText, atPosition: atPosition, searchCardContent: true)
            return !ignoreInput
        }
        insertPair(node: node, "(", ")")
        return false
    }
}
