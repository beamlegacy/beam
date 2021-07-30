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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func preDetectInput(_ input: String) -> Bool {
        guard inputDetectorEnabled else { return true }
        guard let node = focusedWidget as? TextNode else { return true }
        defer { inputDetectorLastInput = input }

        let insertPair = { [unowned self] (left: String, right: String) in
            node.text.insert(right, at: selectedTextRange.upperBound)
            node.text.insert(left, at: selectedTextRange.lowerBound)
            rootNode.cursorPosition += 1
            selectedTextRange = selectedTextRange.lowerBound + 1 ..< selectedTextRange.upperBound + 1
        }

        let handlers: [String: () -> Bool] = [
            "@": { [unowned self] in
                guard popover == nil else { return false }
                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                guard left == " " || pos == 0 else { return true }
                self.showBidirectionalPopover(mode: .internalLink, prefix: 1, suffix: 0)
                return true
            },
            "[": { [unowned self] in
                guard popover == nil else { return false }

                let pos = self.selectedTextRange.isEmpty ? rootNode.cursorPosition : self.selectedTextRange.lowerBound
                let substr = node.text.extract(range: max(0, pos - 1) ..< pos)
                let left = substr.text // capture the left of the cursor to check for an existing [

                if pos > 0 && left == "[" {
                    if !self.selectedTextRange.isEmpty {
                        insertPair("[", "]")
                        node.unproxyElement.makeInternalLink(self.selectedTextRange, createNoteIfNeeded: true)
                        node.text.remove(count: 2, at: self.selectedTextRange.upperBound)
                        node.text.remove(count: 2, at: self.selectedTextRange.lowerBound - 2)
                        self.selectedTextRange = (self.selectedTextRange.lowerBound - 2) ..< (self.selectedTextRange.upperBound - 2)
                        rootNode.cursorPosition = self.selectedTextRange.upperBound
                        return false
                    } else {
                        node.text.insert("]", at: pos)
                        self.showBidirectionalPopover(mode: .internalLink, prefix: 2, suffix: 2)
                        return true
                    }
                } else if pos == 0 || left != "-" {
                    insertPair("[", "]")
                    return false
                }
                return true
            },
            "]": { [unowned self] in
                guard node.text.count >= 2, popover == nil else { return true }
                let startRange = 0..<2
                let substr = node.text.extract(range: startRange)
                if substr.text == "-[" {
                    rootNode.cmdManager.deleteText(in: node, for: startRange)
                    rootNode.cmdManager.formatText(in: node, for: .check(false), with: nil, for: nil, isActive: false)
                    return false
                }
                return true
            },
            "(": { [unowned self] in
                guard popover == nil else { return false }

                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                // capture the left of the cursor to check for an existing (
                if pos > 0 && left == "(" {
                    let initialText = selectedText
                    if !self.selectedTextRange.isEmpty {
                        insertPair("(", ")")
                    } else {
                        node.text.insert(")", at: pos)
                    }
                    self.showBidirectionalPopover(mode: .blockReference, prefix: 2, suffix: 2, initialText: initialText)
                    return true
                }
                insertPair("(", ")")
                return false
            },
            "{": {
                insertPair("{", "}")
                return false
            },
            "\"": {
                insertPair("\"", "\"")
                return false
            },
            "/": { [unowned self] in
                guard popover == nil else { return false }
                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                guard left == " " || pos == 0 else { return true }
                self.showSlashFormatter()
                return true
            },
            " ": { [unowned self] in
                guard popover == nil,
                      self.selectedTextRange.isEmpty
                else { return true }

                let (pos, left) = inputDetectorGetPositionAndPrecedingChar(in: node)
                let range = max(0, pos - 1) ..< pos
                let substr = node.text.extract(range: range)
                if pos > 0 && left == " " && !substr.links.isEmpty {
                    rootNode.state.attributes = BeamText.removeLinks(from: rootNode.state.attributes)
                    rootNode.cmdManager.replaceText(in: node, for: range, with: BeamText(text: " ", attributes: rootNode.state.attributes))
                    return false
                }
                return true
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

                node.element.kind = .quote(level, "", "")
                node.text.removeFirst(level + 1)
                self.rootNode.cursorPosition = 0
            }
            return nil
        }

        let makeBoldOrItalic = { [unowned self] () -> BeamText.Attribute? in
            let isBold = node.text.prefix(2).text == "* "
            let isItalic = node.text.prefix(3).text == "** "

            if node.cursorPosition <= 2, isBold {
                Logger.shared.logInfo("Make Bold", category: .ui)
                node.text.removeFirst(2)
                self.rootNode.cursorPosition = 0
                return .strong
            }

            if node.cursorPosition <= 3, isItalic {
                Logger.shared.logInfo("Make Italic", category: .ui)
                node.text.removeFirst(3)
                self.rootNode.cursorPosition = 0
                return .emphasis
            }
            return nil
        }

        let makeStrikethrough = { [unowned self] () -> BeamText.Attribute? in
            let isStrikethrough = node.text.prefix(3).text == "~~ "
            if node.cursorPosition <= 3, isStrikethrough {
                Logger.shared.logInfo("Make Strikethrough", category: .ui)
                node.text.removeFirst(3)
                self.rootNode.cursorPosition = 0
                return .strikethrough
            }
            return nil
        }

        let makeUnderline = { [unowned self] () -> BeamText.Attribute? in
            let isUnderline = node.text.prefix(3).text == "_ "
            if node.cursorPosition <= 2, isUnderline {
                Logger.shared.logInfo("Make Underline", category: .ui)
                node.text.removeFirst(2)
                self.rootNode.cursorPosition = 0
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

                element.kind = .heading(level)
                element.text.removeFirst(level + 1)
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

}
