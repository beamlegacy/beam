//
//  CommandsTextTests.swift
//  BeamTests
//
//  Created by Jean-Louis Darmon on 18/02/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

@testable import BeamCore
@testable import Beam

class CommandsTextTests: QuickSpec {

    // swiftlint:disable:next function_body_length
    override func spec() {
        var editor: BeamTextEdit!
        var tree: String!
        var rootNode: TextRoot!

        beforeEach {
            // Setup a simple node tree
            let note = self.setupAndResetTree()
            let editor = BeamTextEdit(root: note, journalMode: true)
            editor.prepareRoot()
            rootNode = editor.rootNode!

            tree = """
            TestEditCommands
            \(String.tabs(1))- First bullet
            \(String.tabs(1))- Second bullet

            """
            expect(rootNode.printTree()).to(equal(tree))
            BeamNote.clearCancellables()
        }

        describe("TextNode Editing Commands") {
            beforeEach {
                BeamNote.clearCancellables()

                let note = self.setupAndResetTree()
                editor = BeamTextEdit(root: note, journalMode: true)
                editor.prepareRoot()
                rootNode = editor.rootNode!

                tree = """
                TestEditCommands
                \(String.tabs(1))- First bullet
                \(String.tabs(1))- Second bullet

                """
                expect(rootNode.printTree()).to(equal(tree))


                rootNode.focusedWidget = rootNode.children.first
                rootNode.cursorPosition = 12
            }
            context("in bullet") {
                it("inserts text") {
                    rootNode.insertText(string: " Hello beam !", replacementRange: rootNode.selectedTextRange)

                    let editedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First bullet Hello beam !
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(25))

                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                    expect(rootNode.cursorPosition).to(equal(12))

                    editor.redo(String("Redo"))
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(25))

                    rootNode.cursorPosition = 13
                    rootNode.deleteBackward()
                    rootNode.insertNewline()

                    let newEditedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First bullet
                    Hello beam !
                    \(String.tabs(1))- Second bullet

                    """

                    expect(rootNode.printTree()).to(equal(newEditedTree))
                    expect(rootNode.cursorPosition).to(equal(13))

                    for _ in 0..<2 {
                        editor.undo(String("Undo"))
                    }

                    expect(rootNode.printTree()).to(equal(editedTree))
                    rootNode.cursorPosition = 13

                    for _ in 0..<2 {
                        editor.redo(String("Redo"))
                    }

                    expect(rootNode.printTree()).to(equal(newEditedTree))
                    expect(rootNode.cursorPosition).to(equal(13))
                    BeamNote.clearCancellables()

                }

                it("deletes text") {
                    for _ in 0..<5 {
                        rootNode.deleteBackward()
                    }

                    let editedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First b
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(7))

                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                    expect(rootNode.cursorPosition).to(equal(12))

                    editor.redo(String("Redo"))
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(7))
                    BeamNote.clearCancellables()

                }

                it("deletes text selection") {
                    rootNode.selectedTextRange = 5..<12
                    rootNode.deleteBackward()

                    let editedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(5))
                    expect(rootNode.selectedTextRange.isEmpty).to(equal(true))

                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                    expect(rootNode.cursorPosition).to(equal(12))
                    expect(rootNode.selectedTextRange.lowerBound).to(equal(5))
                    expect(rootNode.selectedTextRange.upperBound).to(equal(12))

                    editor.redo(String("Redo"))
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal((5)))
                    expect(rootNode.selectedTextRange.isEmpty).to(equal(true))
                    BeamNote.clearCancellables()

                }

                it("inserts and delete text") {
                    rootNode.insertText(string: " Hemm", replacementRange: rootNode.selectedTextRange)
                    let editedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First bullet Hemm
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(editedTree))
                    expect(rootNode.cursorPosition).to(equal(17))

                    for _ in 0..<2 {
                        rootNode.deleteBackward()
                    }
                    let deletedEditedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First bullet He
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(deletedEditedTree))
                    expect(rootNode.cursorPosition).to(equal(15))

                    rootNode.insertText(string: "llo", replacementRange: rootNode.selectedTextRange)
                    let insertedEditedTree = """
                    TestEditCommands
                    \(String.tabs(1))- First bullet Hello
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(insertedEditedTree))
                    expect(rootNode.cursorPosition).to(equal(18))

                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(deletedEditedTree))
                    expect(rootNode.cursorPosition).to(equal(15))

                    editor.redo(String("Redo"))
                    expect(rootNode.printTree()).to(equal(insertedEditedTree))
                    expect(rootNode.cursorPosition).to(equal(18))
                    BeamNote.clearCancellables()

                }
            }
        }
    }

    private func setupAndResetTree() -> BeamNote {
        // Setup a simple node tree
        BeamNote.clearCancellables()
        let note = BeamNote.fetchOrCreate(title: "TestEditCommands")

        let bullet1 = BeamElement("First bullet")
        note.addChild(bullet1)
        let bullet2 = BeamElement("Second bullet")
        note.addChild(bullet2)

        return note
    }
}
