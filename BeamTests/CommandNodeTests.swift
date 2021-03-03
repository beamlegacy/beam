//
//  CommandNodeTests.swift
//  BeamTests
//
//  Created by Jean-Louis Darmon on 25/02/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

@testable import Beam
class CommandNodeTests: QuickSpec {
    var note: BeamNote!
    var editor: BeamTextEdit!
    var tree: String!
    var rootNode: TextRoot!

    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("Indentation Commands") {
            it("increases indentation") {
                self.setupTree(alreadyIndented: false)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[1]
                self.rootNode.cursorPosition = 0
                self.rootNode.increaseIndentation()

                let increasedTree = """
                TestCommands
                    v - First bullet
                        - Second bullet

                """
                expect(self.rootNode.printTree()).to(equal(increasedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }

            it("decreases indentation") {
                self.setupTree(alreadyIndented: true)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[0].children.first
                self.rootNode.cursorPosition = 0
                self.rootNode.decreaseIndentation()

                let decreasedTree = """
                TestCommands
                    - First bullet
                    - Second bullet

                """
                expect(self.rootNode.printTree()).to(equal(decreasedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }
        }

        describe("Insert Commands") {
            it("inserts a node on a not intented tree") {
                self.setupTree(alreadyIndented: false)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[1]
                self.rootNode.cursorPosition = 0
                self.editor.pressEnter(false, false, false)
                var insertedTree = """
                TestCommands
                    - First bullet
                    - 
                    - Second bullet

                """
                expect(self.rootNode.printTree()).to(equal(insertedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.cursorPosition = 6
                self.editor.pressEnter(false, false, false)

                insertedTree = """
                TestCommands
                    - First bullet
                    - Second
                    -  bullet

                """
                expect(self.rootNode.printTree()).to(equal(insertedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.cursorPosition = 13
                self.editor.pressEnter(false, false, false)

                insertedTree = """
                TestCommands
                    - First bullet
                    - Second bullet
                    - 

                """

                expect(self.rootNode.printTree()).to(equal(insertedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }
        }

        describe("Delete Commands") {
            it("deletes node backward") {
                self.setupTree(alreadyIndented: false)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[1]
                self.rootNode.cursorPosition = 0
                self.rootNode.deleteBackward()

                let deletedBackwardTree = """
                TestCommands
                    - First bulletSecond bullet

                """
                expect(self.rootNode.printTree()).to(equal(deletedBackwardTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }
            it("deletes node forward") {
                self.setupTree(alreadyIndented: false)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[0]
                self.rootNode.cursorPosition = 12
                self.rootNode.deleteForward()

                let deletedForwardTree = """
                TestCommands
                    - First bulletSecond bullet

                """
                expect(self.rootNode.printTree()).to(equal(deletedForwardTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }

            it("deletes a selection of nodes") {
                self.setupTree(alreadyIndented: false)
                expect(self.rootNode.printTree()).to(equal(self.tree))

                self.rootNode.focussedWidget = self.rootNode.children[0]
                self.rootNode.startNodeSelection()
                self.rootNode.extendNodeSelectionDown()
                self.rootNode.deleteBackward()

                let deletedTree = """
                TestCommands
                    - 

                """
                expect(self.rootNode.printTree()).to(equal(deletedTree))
                self.editor.undo(String("Undo"))
                expect(self.rootNode.printTree()).to(equal(self.tree))
            }
        }
    }

    private func setupTree(alreadyIndented: Bool) {
        self.note = BeamNote(title: "TestCommands")
        let bullet1 = BeamElement("First bullet")
        self.note.addChild(bullet1)

        self.editor = BeamTextEdit(root: self.note, journalMode: true)
        self.rootNode = self.editor.rootNode

        let bullet2 = BeamElement("Second bullet")
        if alreadyIndented {
            (rootNode.children.first as? TextNode)?.element.addChild(bullet2)
            self.tree = """
            TestCommands
                v - First bullet
                    - Second bullet

            """
        } else {
            self.note.addChild(bullet2)
            self.tree = """
            TestCommands
                - First bullet
                - Second bullet

            """
        }
    }
}
