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

    func validateNodeWithElement(node: TextNode, element: BeamElement) {
        XCTAssert(node.element === element)
        XCTAssertEqual(node.text, element.text)

        let elements = element.children
        XCTAssertEqual(node.children.count, elements.count)

        for i in 0..<node.children.count {
            let childNode = node.children[i]
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
            - Links

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

        root.children.first?.open.toggle()
        let str1 = """
        title
            > - bullet1
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - Links

        """

        XCTAssertEqual(str1, root.printTree())
    }

    func testRemoveNode() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        root.removeChild(root.children.first!)

        let str1 = """
        title
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - Links

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
            - Links

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
            - Links

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

        root.children.first?.addChild(TextNode(editor: editor, element: BeamElement("bullet13")))

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
            - Links

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

        _ = root.children.first?.insert(node: TextNode(editor: editor, element: BeamElement("bullet3")), after: root.children.first!.children.first!)

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
            - Links

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
        node.addChild(TextNode(editor: editor, element: BeamElement("bullet131")))
        root.children.first?.addChild(node)

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
            - Links

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
        node.addChild(TextNode(editor: editor, element: BeamElement("bullet131")))
        _ = root.children.first?.insert(node: node, after: root.children.first!.children.first!)

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
            - Links

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

        root.removeChild(root.children.first!)
        let str1 = """
        title
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - Links

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

        root.children.first!.removeChild(root.children.first!.children.first!)
        let str1 = """
        title
            v - bullet1
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - Links

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
            - Links

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
            - Links

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
            - Links

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
            - Links

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
            - Links

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
            - Links

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
    func testMoveCursor() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        //print("Tree:\n\(root.printTree())\n")
        validateRootWithNote(root: root, note: note)

        root.node = root.children.first

        root.cursorPosition = 3
        root.selectedTextRange = 3..<7
        root.setLayout(NSRect(x: 0, y: 0, width: 400, height: 500))
        let str = """
        title
            v - bullet1
                - bullet11
                - bullet12
            v - bullet2
                - bullet21
                - bullet22
                - bullet23
            - Links

        """

        root.doCommand(.moveLeft)
        XCTAssertEqual(str, root.printTree())
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssert(root.selectedTextRange.isEmpty)

        root.doCommand(.moveLeft)
        XCTAssertEqual(root.cursorPosition, 2)
        XCTAssert(root.selectedTextRange.isEmpty)

        root.doCommand(.moveRight)
        XCTAssertEqual(root.cursorPosition, 3)
        XCTAssert(root.selectedTextRange.isEmpty)

        root.doCommand(.moveRight)
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssert(root.selectedTextRange.isEmpty)

        root.doCommand(.moveRightAndModifySelection)
        root.doCommand(.moveRightAndModifySelection)
        root.doCommand(.moveRightAndModifySelection)
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssertEqual(root.selectedTextRange, 4..<7)

        root.cancelSelection()
        XCTAssertEqual(root.cursorPosition, 7)
        XCTAssert(root.selectedTextRange.isEmpty)
        root.doCommand(.moveLeftAndModifySelection)
        root.doCommand(.moveLeftAndModifySelection)
        root.doCommand(.moveLeftAndModifySelection)
        XCTAssertEqual(root.cursorPosition, 4)
        XCTAssertEqual(root.selectedTextRange, 4..<7)

        root.doCommand(.moveDown)
        XCTAssert(root.node !== root.children.first)
        XCTAssert(root.node === root.children.first?.children.first)
        root.doCommand(.moveUp)
        XCTAssert(root.node === root.children.first)
        validateRootWithNote(root: root, note: note)
    }

    // swiftlint:disable:next function_body_length
    func testMoveAndEdit() {
        defer { reset() }
        let frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        let note = createLoremArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        validateRootWithNote(root: root, note: note)

        root.node = root.children.first
        root.cursorPosition = 0
        root.setLayout(frame)
        root.updateRendering()

        let expanded1 = "Lorem **ipsum dolor** sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

        for i in 0..<5 {
            root.doCommand(.moveRight)
            root.setLayout(frame)
            root.updateRendering()
            XCTAssertEqual(root.node.attributedString.string, String.loremIpsumSmall)
            XCTAssertEqual(root.cursorPosition, i + 1)
        }

        root.doCommand(.moveRight)
        root.setLayout(frame)
        root.updateRendering()
        XCTAssertEqual(root.node.attributedString.string, expanded1)
        XCTAssertEqual(root.cursorPosition, 8)

        for _ in 0..<11 {
            root.doCommand(.moveRightAndModifySelection)
            root.setLayout(frame)
            root.updateRendering()
        }
        XCTAssertEqual(root.cursorPosition, 8 + 11)
        XCTAssertEqual(root.selectedText, "ipsum dolor")

        root.doCommand(.deleteBackward)
        XCTAssertEqual(root.cursorPosition, 8)
        XCTAssertEqual(root.node.text.text, "Lorem **** sit amet, *consectetur* adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore **_magna aliqua_**.")

        root.doCommand(.deleteBackward)
        root.doCommand(.deleteBackward)
        XCTAssertEqual(root.cursorPosition, 6)
        XCTAssertEqual(root.node.text.text, "Lorem ** sit amet, *consectetur* adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore **_magna aliqua_**.")

        root.doCommand(.deleteForward)
        root.doCommand(.deleteForward)
        root.doCommand(.deleteForward)
        XCTAssertEqual(root.cursorPosition, 6)
        XCTAssertEqual(root.node.text.text, "Lorem sit amet, *consectetur* adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore **_magna aliqua_**.")
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
        XCTAssertEqual(root.node.text.text, "bullet1bullet11")
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
        root.cursorPosition = root.node.text.count
        root.setLayout(frame)
        root.updateRendering()

        XCTAssertEqual(root.children.first?.children.count, 2)
        root.doCommand(.deleteForward)
//        print("Tree:\n\(root.printTree())\n")
//        note.debugNote()
        XCTAssertEqual(root.node.text.text, "bullet11bullet12")
        XCTAssertEqual(root.children.first?.children.count, 1)
        validateRootWithNote(root: root, note: note)
    }

    func testStrippedText() {
        defer { reset() }
        let note = createMiniArborescence(title: "title")
        let editor = BeamTextEdit(root: note)
        let root = editor.rootNode!
        XCTAssertEqual(" bullet1 bullet11 bullet12 bullet2 bullet21 bullet22 bullet23 Links", root.fullStrippedText)

    }

    func testLematizationEN() {
        defer { reset() }
        let text = "This is a Swift port of Ruby's Faker library that generates fake data. Are you still bothered with meaningless randomly character strings? Just relax and leave this job to Fakery. It's useful in all the cases when you need to use some dummy data for testing, population of database during development, etc. NOTE: Generated data is pretty realistic, supports a range of locales, but returned values are not guaranteed to be unique."

        let tagger = NLTagger(tagSchemes: [.lemma])

        tagger.string = text
//        tagger.setLanguage(.french, range: text.startIndex ..< text.endIndex)
        let range = text.startIndex ..< text.endIndex
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        print("Found language: \(String(describing: tagger.dominantLanguage))")
        XCTAssertEqual(tagger.dominantLanguage, .english)

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange -> Bool in
            if let lemma = tag?.rawValue {
                // Do something with each lemma
//                let range = text.range(from: tokenRange.lowerBound ..< tokenRange.upperBound)
                let range = text[tokenRange]
                print("Lema: \(range) -> \(lemma)")
            }

            return true
        }
    }

    func testLematizationFR() {
        defer { reset() }
        let text = "Le Monde et des tiers selectionnés, notamment des partenaires publicitaires, utilisent des cookies ou des technologies similaires. Les cookies nous permettent d’accéder à, d’analyser et de stocker des informations telles que les caractéristiques de votre terminal ainsi que certaines données personnelles (par exemple : adresses IP, données de navigation, d’utilisation ou de géolocalisation, identifiants uniques)."

        let tagger = NLTagger(tagSchemes: [.lemma])

        tagger.string = text
//        tagger.setLanguage(.french, range: text.startIndex ..< text.endIndex)
        let range = text.startIndex ..< text.endIndex
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        print("Found language: \(String(describing: tagger.dominantLanguage))")
        XCTAssertEqual(tagger.dominantLanguage, .french)

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange -> Bool in
            if let lemma = tag?.rawValue {
                // Do something with each lemma
//                let range = text.range(from: tokenRange.lowerBound ..< tokenRange.upperBound)
                let range = text[tokenRange]
                print("Lema: \(range) -> \(lemma)")
            }

            return true
        }
    }

}
