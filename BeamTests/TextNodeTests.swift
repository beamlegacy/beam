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
        let note = BeamNote(title: title)
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

    func testLoadExistingNote() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
    }

    func testFoldNode() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let node = root.children.first as? TextNode
        node?.open.toggle()
        let str1 = """
        title
            > - bullet1
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
    }

    func testRemoveNode() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        root.element.removeChild((root.children.first as! TextNode).element)

        let str1 = """
        title
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testAddNodeToRoot() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let bullet3 = BeamElement("bullet3")
        root.addChild(TextNode(editor: editor, element: bullet3))

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - bullet3

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testInsertNodeIntoRoot() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        _ = root.insert(node: TextNode(editor: editor, element: BeamElement("bullet3")), after: root.children.first!)

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            - bullet3
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testAddNodeToBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        (root.children.first as? TextNode)?.element.addChild(BeamElement("bullet13"))

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet12
                - bullet13
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testInsertNodeIntoBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        _ = first?.element.insert(BeamElement("bullet3"), after: first!.element.children.first)

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet3
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testAddTreeToBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let node = TextNode(editor: editor, element: BeamElement("bullet13"))
        node.element.addChild(BeamElement("bullet131"))
        let first = root.children.first as? TextNode
        first?.element.addChild(node.element)

        let str1 = """
        title
            v - bullet1
                - bullet11
                - bullet12
                v - bullet13
                    - bullet131
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testInsertTreeIntoBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        let node = TextNode(editor: editor, element: BeamElement("bullet13"))
        node.element.addChild(BeamElement("bullet131"))
        let first = root.children.first as? TextNode
        _ = first?.element.insert(node.element, after: first!.element.children.first!)

        let str1 = """
        title
            v - bullet1
                - bullet11
                v - bullet13
                    - bullet131
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testRemoveBulletFromNote() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        root.element.removeChild(first!.element)
        let str1 = """
        title
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    func testRemoveBulletFromBullet() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        let first = root.children.first as? TextNode
        first?.element.removeChild(first!.element.children.first!)
        let str1 = """
        title
            v - bullet1
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testInsertText1() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.node = root.children.first
        root.cursorPosition = 0
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
            v - testbullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        root.undoManager.undo()

        let str2 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 0)
        XCTAssert(root.selectedTextRange.isEmpty)

        // redo the text insertion:
        root.undoManager.redo()
        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssert(root.selectedTextRange.isEmpty)

        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testInsertText2() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.node = root.children.first
        root.cursorPosition = 3
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
            v - bultestlet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        root.undoManager.undo()

        let str2 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssert(root.selectedTextRange.isEmpty)

        // redo the text insertion:
        root.undoManager.redo()
        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)
        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testInsertText3() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        // Insert some text:
        root.node = root.children.first
        root.cursorPosition = 3
        root.selectedTextRange = 3..<7
        root.insertText(string: "test", replacementRange: root.selectedTextRange)
        let str1 = """
        title
            v - bultest
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """

        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)

        // Undo the text insertion:
        root.undoManager.undo()

        let str2 = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23

        """
        XCTAssertEqual(str2, root.printTree())
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssertEqual(root.selectedTextRange, 3..<7)

        // redo the text insertion:
        root.undoManager.redo()
        XCTAssertEqual(str1, root.printTree())
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)
        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testDeleteBackward() {
        defer { reset() }
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        root.node = root.children.first?.children.first
        root.cursorPosition = 0
        root.setLayout(frame)
        root.updateRendering()

        XCTAssertEqual(root.children.first?.children.count, 2)
        root.doCommand(.deleteBackward)
        XCTAssertNotNil(root.node as? TextNode)
        if let node = root.node as? TextNode {
            XCTAssertEqual(node.text.text, "bullet1bullet11")
        }
        XCTAssertEqual(root.children.first?.children.count, 1)
//        print("Tree:\n\(root.printTree())\n")
//        note.debugNote()
        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testDeleteForward() {
        defer { reset() }
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
//        print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        root.node = root.children.first?.children.first
        XCTAssertNotNil(root.node as? TextNode)
        if let node = root.node as? TextNode {
            root.cursorPosition = node.text.count
        }
        root.setLayout(frame)
        root.updateRendering()

        XCTAssertEqual(root.children.first?.children.count, 2)
        root.doCommand(.deleteForward)
//        print("Tree:\n\(root.printTree())\n")
//        note.debugNote()
        XCTAssertNotNil(root.node as? TextNode)
        if let node = root.node as? TextNode {
            XCTAssertEqual(node.text.text, "bullet11bullet12")
        }
        XCTAssertEqual(root.children.first?.children.count, 1)
        validateRootWithNote(root: root, note: note)
    }

    func testStrippedText() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        XCTAssertEqual(" bullet1 bullet11 bullet12 bullet2 bullet21 bullet22 bullet23", root.fullStrippedText)

    }
}
