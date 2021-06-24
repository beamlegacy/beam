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
                        node.text.makeInternalLink(self.selectedTextRange)
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
                } else if pos == 0 && left == " " {
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

    // swiftlint:disable:next cyclomatic_complexity
    func postDetectInput(_ input: String) {
        guard inputDetectorEnabled else { return }
        guard let node = focusedWidget as? TextNode else { return }

        let makeQuote = { [unowned self] in
            let level1 = node.text.prefix(2).text == "> "
            let level2 = node.text.prefix(3).text == ">> "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level > 0 {
                Logger.shared.logInfo("Make quote", category: .ui)

                node.element.kind = .quote(level, "", "")
                node.text.removeFirst(level + 1)
                self.rootNode.cursorPosition = 0
            }
        }

        let makeHeader = { [unowned self] in
            let level1 = node.text.prefix(2).text == "# "
            let level2 = node.text.prefix(3).text == "## "
            let level = level1 ? 1 : (level2 ? 2 : 0)
            if node.cursorPosition <= 3, level != 0 {
                Logger.shared.logInfo("Make header", category: .ui)

                // In this case we will reparent all following sibblings that are not a header to the current node as Paper does
                guard self.focusedWidget?.isEmpty ?? false else { return }
                guard let node = self.focusedWidget as? TextNode else { return }
                let element = node.element
                guard let parentNode = self.focusedWidget?.parent as? TextNode else { return }
                let parent = parentNode.element
                guard let index = self.focusedWidget?.indexInParent else { return }
                for sibbling in parent.children.suffix(from: index + 1) {
                    guard !sibbling.isHeader else { return }
                    element.addChild(sibbling)
                }

                element.kind = .heading(level)
                element.text.removeFirst(level + 1)
                self.rootNode.cursorPosition = 0
            }
        }

        let handlers: [String: () -> Void] = [
            "#": makeHeader,
            ">": makeQuote,
            " ": { //[unowned self] in
                makeHeader()
                makeQuote()
            }
        ]

        if let handler = handlers[input] {
            handler()
        } else if let handler = handlers[inputDetectorLastInput + input] {
            handler()
        }
    }

}
