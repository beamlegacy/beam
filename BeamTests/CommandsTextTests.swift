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

@testable import Beam
class CommandsTextTests: QuickSpec {
    var note: BeamNote!
    var editor: BeamTextEdit!
    var tree: String!
    var rootNode: TextRoot!

    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeSuite {
            // Setup a simple node tree
            self.setupAndResetTree()
            expect(self.rootNode.printTree()).to(equal(self.tree))
        }

        describe("TextNode Editing Commands") {
            beforeEach {
                self.rootNode.focussedWidget = self.rootNode.children.first
                self.rootNode.cursorPosition = 12
            }
            afterEach {
                self.setupAndResetTree()
            }
            context("in bullet") {
                it("inserts text") {
                    self.rootNode.insertText(string: " Hello beam !", replacementRange: self.rootNode.selectedTextRange)

                    let editedTree = """
                    TestEditCommands
                        - First bullet Hello beam !
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(25))

                    self.editor.undo(String("Undo"))
                    expect(self.rootNode.printTree()).to(equal(self.tree))
                    expect(self.rootNode.cursorPosition).to(equal(12))

                    self.editor.redo(String("Redo"))
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(25))

                    self.rootNode.cursorPosition = 13
                    self.rootNode.deleteBackward()
                    self.rootNode.insertNewline()

                    let newEditedTree = """
                    TestEditCommands
                        - First bullet
                    Hello beam !
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(newEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(0))

                    for _ in 0..<2 {
                        self.editor.undo(String("Undo"))
                    }

                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    self.rootNode.cursorPosition = 13

                    for _ in 0..<2 {
                        self.editor.redo(String("Redo"))
                    }

                    expect(self.rootNode.printTree()).to(equal(newEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(0))
                }

                it("deletes text") {
                    for _ in 0..<5 {
                        self.rootNode.deleteBackward()
                    }

                    let editedTree = """
                    TestEditCommands
                        - First b
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(7))

                    self.editor.undo(String("Undo"))
                    expect(self.rootNode.printTree()).to(equal(self.tree))
                    expect(self.rootNode.cursorPosition).to(equal(12))

                    self.editor.redo(String("Redo"))
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(7))
                }

                it("deletes text selection") {
                    self.rootNode.selectedTextRange = 5..<12
                    self.rootNode.deleteBackward()

                    let editedTree = """
                    TestEditCommands
                        - First
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(5))
                    expect(self.rootNode.selectedTextRange.isEmpty).to(equal(true))

                    self.editor.undo(String("Undo"))
                    expect(self.rootNode.printTree()).to(equal(self.tree))
                    expect(self.rootNode.cursorPosition).to(equal(12))
                    expect(self.rootNode.selectedTextRange.lowerBound).to(equal(5))
                    expect(self.rootNode.selectedTextRange.upperBound).to(equal(12))

                    self.editor.redo(String("Redo"))
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal((5)))
                    expect(self.rootNode.selectedTextRange.isEmpty).to(equal(true))
                }

                it("inserts and delete text") {
                    self.rootNode.insertText(string: " Hemm", replacementRange: self.rootNode.selectedTextRange)
                    let editedTree = """
                    TestEditCommands
                        - First bullet Hemm
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(editedTree))
                    expect(self.rootNode.cursorPosition).to(equal(17))

                    for _ in 0..<2 {
                        self.rootNode.deleteBackward()
                    }
                    let deletedEditedTree = """
                    TestEditCommands
                        - First bullet He
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(deletedEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(15))

                    self.rootNode.insertText(string: "llo", replacementRange: self.rootNode.selectedTextRange)
                    let insertedEditedTree = """
                    TestEditCommands
                        - First bullet Hello
                        - Second bullet

                    """
                    expect(self.rootNode.printTree()).to(equal(insertedEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(18))

                    self.editor.undo(String("Undo"))
                    expect(self.rootNode.printTree()).to(equal(deletedEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(15))

                    self.editor.redo(String("Redo"))
                    expect(self.rootNode.printTree()).to(equal(insertedEditedTree))
                    expect(self.rootNode.cursorPosition).to(equal(18))
                }
            }
        }
    }

    private func setupAndResetTree() {
        // Setup a simple node tree
        self.note = BeamNote(title: "TestEditCommands")
        let bullet1 = BeamElement("First bullet")
        self.note.addChild(bullet1)
        let bullet2 = BeamElement("Second bullet")
        self.note.addChild(bullet2)

        self.editor = BeamTextEdit(root: self.note, journalMode: true)
        self.rootNode = self.editor.rootNode

        self.tree = """
        TestEditCommands
            - First bullet
            - Second bullet

        """
    }
}
