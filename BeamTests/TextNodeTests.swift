//
//  TextNodeTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 26/10/2020.
//

// swiftlint:disable type_body_length file_length

import Foundation
import XCTest
@testable import Beam
@testable import BeamCore
import NaturalLanguage
import Fakery

class TextNodeTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func reset() {
    }

    func validateNodeWithElement(node: Widget, element: BeamElement) {
        guard let node = node as? TextNode else { return }
        XCTAssert(node.element === element)
        XCTAssertEqual(node.text, element.text)

        let elements = element.children
        XCTAssertEqual(node.children.count, elements.count)

        for i in 0..<node.children.count {
            guard let childNode = node.children[i] as? TextNode else { continue }
            let childElement = elements[i]

            validateNodeWithElement(node: childNode, element: childElement)
        }

    }

    func validateRootWithNote(root: TextRoot, note: BeamNote) {
        let elements = note.children
        XCTAssertEqual(root.element.children.count, elements.count)

        for i in 0..<min(root.element.children.count, elements.count) {
            let node = root.children[i]
            let element = elements[i]

            validateNodeWithElement(node: node, element: element)
        }
    }

    func createMiniArborescence(title: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(title: title)
        let bullet1 = BeamElement("bullet1")
        note.addChild(bullet1)
        let bullet11 = BeamElement("bullet11")
        bullet1.addChild(bullet11)
        bullet1.addChild(BeamElement("bullet12"))
        let bullet2 = BeamElement("bullet2")
        note.addChild(bullet2)
        bullet2.addChild(BeamElement("bullet21"))
        bullet2.addChild(BeamElement("bullet22"))
        bullet2.addChild(BeamElement("bullet23"))

        return note
    }

    func createLoremArborescence(title: String) -> BeamNote {
        let note = BeamNote(title: title)
        let bullet1 = BeamElement(String.loremIpsumSmallMD)
        note.addChild(bullet1)
        let bullet11 = BeamElement(String.loremIpsumSmallMD)
        bullet1.addChild(bullet11)
        bullet1.addChild(BeamElement(String.loremIpsumSmallMD))
        let bullet2 = BeamElement(String.loremIpsumSmallMD)
        note.addChild(bullet2)
        bullet2.addChild(BeamElement(String.loremIpsumSmallMD))
        bullet2.addChild(BeamElement(String.loremIpsumSmallMD))
        bullet2.addChild(BeamElement(String.loremIpsumSmallMD))

        return note
    }

    var editor: BeamTextEdit!

    func createNodeWithInternalLink() -> TextNode {
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        note.addChild(BeamElement("before link "))
        let linkElement = BeamText(text: "My Internal Note", attributes: [
            .internalLink(UUID.null)
        ])
        root.focusedWidget = root.children.last { $0 is TextNode }
        XCTAssertNotNil(root.focusedWidget as? TextNode)
        let node = root.focusedWidget as? TextNode
        root.cursorPosition = node!.text.count
        root.insertText(text: linkElement, replacementRange: nil)
        root.insertText(text: BeamText(text: " after link", attributes: []), replacementRange: nil)
        return node!
    }

    func testLoadExistingNote() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        BeamNote.clearCancellables()
    }

    func testFoldNode() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let node = root.children.first as? TextNode
        node?.open.toggle()
        let str1 = """
        title
        \(String.tabs(1))> - bullet1
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        BeamNote.clearCancellables()
    }

    func testRemoveNode() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        // swiftlint:disable:next force_cast
        root.element.removeChild((root.children.first as! TextNode).element)

        let str1 = """
        title
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testAddNodeToRoot() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let bullet3 = BeamElement("bullet3")
        root.addChild(TextNode(parent: root, element: bullet3, availableWidth: 600))

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23
        \(String.tabs(1))- bullet3

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    // MARK: - Insert
    func testInsertNodeIntoRoot() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        _ = root.insert(node: TextNode(parent: root, element: BeamElement("bullet3"), availableWidth: 600), after: root.children.first!)

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))- bullet3
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testAddNodeToBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        (root.children.first as? TextNode)?.element.addChild(BeamElement("bullet13"))

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(2))- bullet13
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testInsertNodeIntoBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        _ = first?.element.insert(BeamElement("bullet3"), after: first!.element.children.first)

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet3
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testAddTreeToBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let node = TextNode(parent: root, element: BeamElement("bullet13"), availableWidth: 600)
        node.element.addChild(BeamElement("bullet131"))
        let first = root.children.first as? TextNode
        first?.element.addChild(node.element)

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(2))v - bullet13
        \(String.tabs(3))- bullet131
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testInsertTreeIntoBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let node = TextNode(parent: root, element: BeamElement("bullet13"), availableWidth: 600)
        node.element.addChild(BeamElement("bullet131"))
        let first = root.children.first as? TextNode
        _ = first?.element.insert(node.element, after: first!.element.children.first!)

        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))v - bullet13
        \(String.tabs(3))- bullet131
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testRemoveBulletFromNote() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        root.element.removeChild(first!.element)
        let str1 = """
        title
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testRemoveBulletFromBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        first?.element.removeChild(first!.element.children.first!)
        let str1 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    // swiftlint:disable:next function_body_length
    func testInsertText1() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.focusedWidget = root.children.first
        root.cursorPosition = 0
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
        \(String.tabs(1))v - testbullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        editor.undo(String("Undo"))

        let str2 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 0)
        XCTAssert(root.selectedTextRange.isEmpty)

        // redo the text insertion:
        editor.redo(String("Redo"))
        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssert(root.selectedTextRange.isEmpty)

        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    // swiftlint:disable:next function_body_length
    func testInsertText2() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.focusedWidget = root.children.first
        root.cursorPosition = 3
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
        \(String.tabs(1))v - bultestlet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        editor.undo(String("Undo"))

        let str2 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssert(root.selectedTextRange.isEmpty)

        // redo the text insertion:
        editor.redo(String("Redo"))
        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    // swiftlint:disable:next function_body_length
    func testInsertText3() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.focusedWidget = root.children.first
        root.cursorPosition = 3
        root.selectedTextRange = 3..<7
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
        \(String.tabs(1))v - bultest
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        editor.undo(String("Undo"))

        let str2 = """
        title
        \(String.tabs(1))v - bullet1
        \(String.tabs(2))- bullet11
        \(String.tabs(2))- bullet12
        \(String.tabs(1))v - bullet2
        \(String.tabs(2))- bullet21
        \(String.tabs(2))- bullet22
        \(String.tabs(2))- bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssertEqual(root.selectedTextRange, 3..<7)

        // redo the text insertion / selection deletion:
        editor.redo(String("Redo"))
        editor.redo(String("Redo"))

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testInsertTextAroundInternalLink() {
        defer { reset() }
        let node = createNodeWithInternalLink()
        guard let root = node.editor?.rootNode else { XCTFail("RootNode isn't attached to an editor."); return }
        XCTAssertEqual(node.text.text, "before link My Internal Note after link")
        root.cursorPosition = 28
        root.selectedTextRange = 28..<28
        root.insertText(string: " Beam", replacementRange: nil)
        XCTAssertEqual(node.text.text, "before link My Internal Note Beam after link")
        root.cursorPosition = 12
        root.selectedTextRange = 12..<12
        root.insertText(string: "Hello ", replacementRange: nil)
        XCTAssertEqual(node.text.text, "before link Hello My Internal Note Beam after link")

        BeamNote.clearCancellables()
    }

    func testInsertTextInsideInternalLink() {
        defer { reset() }
        let node = createNodeWithInternalLink()
        guard let root = node.editor?.rootNode else { XCTFail("RootNode isn't attached to an editor."); return }
        XCTAssertEqual(node.text.text, "before link My Internal Note after link")
        root.cursorPosition = 20
        root.selectedTextRange = 20..<20
        root.insertText(string: "Hello Beam", replacementRange: nil)
        XCTAssertEqual(node.text.text, "before link Hello Beam after link")

        BeamNote.clearCancellables()
    }

    // MARK: - Delete
    // swiftlint:disable:next function_body_length
    func testDeleteBackward() {
        defer { reset() }
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        guard let root = editor?.rootNode else { XCTFail("RootNode isn't attached to an editor."); return }
        validateRootWithNote(root: root, note: note)

        root.focusedWidget = root.children.first?.children.first
        root.cursorPosition = 0
        root.setLayout(frame)
        root.computeRendering()

        XCTAssertEqual(root.children.first?.children.count, 2)
        root.deleteBackward()
        XCTAssertNotNil(root.focusedWidget as? TextNode)
        if let node = root.focusedWidget as? TextNode {
            XCTAssertEqual(node.text.text, "bullet1bullet11")
        }
        XCTAssertEqual(root.children.first?.children.count, 1)
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
//        note.debugNote()
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testDeleteBackwardAfterLink() {
        defer { reset() }
        let node = createNodeWithInternalLink()
        guard let root = node.editor?.rootNode else { XCTFail("RootNode isn't attached to an editor."); return }
        root.cursorPosition = 29
        XCTAssertEqual(node.text.text, "before link My Internal Note after link")
        root.deleteBackward()
        XCTAssertEqual(node.text.text, "before link My Internal Noteafter link")
        root.deleteBackward()
        XCTAssertEqual(node.text.text, "before link after link")
        BeamNote.clearCancellables()
    }

    // swiftlint:disable:next function_body_length
    func testDeleteForward() {
        defer { reset() }
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        root.focusedWidget = root.children.first?.children.first
        XCTAssertNotNil(root.focusedWidget as? TextNode)
        if let node = root.focusedWidget as? TextNode {
            root.cursorPosition = node.text.count
        }
        root.setLayout(frame)
        root.computeRendering()

        XCTAssertEqual(root.children.first?.children.count, 2)
        root.deleteForward()
//        Logger.shared.logDebug("Tree:\n\(root.printTree())\n")
//        note.debugNote()
        XCTAssertNotNil(root.focusedWidget as? TextNode)
        if let node = root.focusedWidget as? TextNode {
            XCTAssertEqual(node.text.text, "bullet11bullet12")
        }
        XCTAssertEqual(root.children.first?.children.count, 1)
        validateRootWithNote(root: root, note: note)
        BeamNote.clearCancellables()
    }

    func testDeleteForwardBeforeLink() {
        defer { reset() }
        let node = createNodeWithInternalLink()
        guard let root = node.editor?.rootNode else { XCTFail("RootNode isn't attached to an editor."); return }
        XCTAssertEqual(node.text.text, "before link My Internal Note after link")
        root.cursorPosition = 11
        root.deleteForward()
        XCTAssertEqual(node.text.text, "before linkMy Internal Note after link")
        root.deleteForward()
        XCTAssertEqual(node.text.text, "before link after link")
        BeamNote.clearCancellables()
    }

    // MARK: - Stripped Text
    func testStrippedText() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        XCTAssertEqual(" bullet1 bullet11 bullet12 bullet2 bullet21 bullet22 bullet23", root.fullStrippedText)
        BeamNote.clearCancellables()
    }

    // MARK: - Links finder
    func testExternalLinkFinder() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        editor = BeamTextEdit(root: note, journalMode: true)
        editor.prepareRoot()
        let root = editor.rootNode!
        note.addChild(BeamElement("before link "))
        let linkElement = BeamText(text: "ExternalLink.com", attributes: [
            .link("externallink.com")
        ])
        root.focusedWidget = root.children.last { $0 is TextNode }
        XCTAssertNotNil(root.focusedWidget as? TextNode)
        guard let node = root.focusedWidget as? TextNode else {
            return
        }
        root.cursorPosition = node.text.count
        root.insertText(text: linkElement, replacementRange: nil)
        root.insertText(text: BeamText(text: " after link", attributes: []), replacementRange: nil)

        XCTAssertEqual(node.linkAt(index: 15)?.absoluteString, "externallink.com")
        XCTAssertNil(node.linkAt(index: 12))
        XCTAssertNil(node.linkAt(index: 29))

        XCTAssertTrue(node.linkRangeAt(index: 15)?.attributes.contains { $0.isLink } ?? false)
        XCTAssertNil(node.linkRangeAt(index: 12))
        XCTAssertNil(node.linkRangeAt(index: 29))

        BeamNote.clearCancellables()
    }

    func testInternalLinkFinder() {
        defer { reset() }
        let node = createNodeWithInternalLink()

        XCTAssertEqual(node.internalLinkAt(index: 15), UUID.null)
        XCTAssertNil(node.internalLinkAt(index: 12))
        XCTAssertNil(node.internalLinkAt(index: 29))

        XCTAssertTrue(node.internalLinkRangeAt(index: 15)?.attributes.contains { $0.isInternalLink } ?? false)
        XCTAssertNil(node.internalLinkRangeAt(index: 12))
        XCTAssertNil(node.internalLinkRangeAt(index: 29))

        BeamNote.clearCancellables()
    }

}
