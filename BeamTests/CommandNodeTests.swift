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
@testable import BeamCore

class CommandNodeTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        var editor: BeamTextEdit!
        var tree: String!
        var rootNode: TextRoot!

        beforeEach {
            let note = self.setupTree()
            let bullet2 = BeamElement("Second bullet")
            note.addChild(bullet2)
            let editor = BeamTextEdit(root: note, journalMode: true)
            editor.prepareRoot()
            rootNode = editor.rootNode!

            let tree = """
            TestCommands
            \(String.tabs(1))- First bullet
            \(String.tabs(1))- Second bullet

            """

            expect(rootNode.printTree()).to(equal(tree))
            BeamNote.clearCancellables()
        }

        describe("Indented tree") {
            beforeEach {
                BeamNote.clearCancellables()
                let note = self.setupTree()
                let bullet2 = BeamElement("Second bullet")

                editor = BeamTextEdit(root: note, journalMode: true)
                editor.prepareRoot()
                rootNode = editor.rootNode!
                (rootNode.children.first as? TextNode)?.element.addChild(bullet2)

                tree = """
                TestCommands
                \(String.tabs(1))v - First bullet
                \(String.tabs(2))- Second bullet

                """

                expect(rootNode.printTree()).to(equal(tree))
            }
            afterEach {
                BeamNote.clearCancellables()
            }
            context("Decrease") {
                it("decreases indentation") {

                    rootNode.focusedWidget = rootNode.children[0].children.first
                    rootNode.cursorPosition = 0
                    rootNode.decreaseIndentation()

                    let decreasedTree = """
                    TestCommands
                    \(String.tabs(1))- First bullet
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(decreasedTree))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }
            }

        }

        describe("Not Intended") {
            beforeEach {
                BeamNote.clearCancellables()
                let note = self.setupTree()
                let bullet2 = BeamElement("Second bullet")
                note.addChild(bullet2)
                editor = BeamTextEdit(root: note, journalMode: true)
                editor.prepareRoot()
                rootNode = editor.rootNode!

                tree = """
                TestCommands
                \(String.tabs(1))- First bullet
                \(String.tabs(1))- Second bullet

                """

                expect(rootNode.printTree()).to(equal(tree))
            }
            afterEach {
                BeamNote.clearCancellables()
            }
            context("Insert & Increase") {
                it("increases indentation") {
                    rootNode.focusedWidget = rootNode.children[1]
                    rootNode.cursorPosition = 0
                    rootNode.increaseIndentation()

                    let increasedTree = """
                    TestCommands
                    \(String.tabs(1))v - First bullet
                    \(String.tabs(2))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(increasedTree))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }

                it("inserts a node on a not intented tree") {
                    rootNode.focusedWidget = rootNode.children[1]
                    rootNode.cursorPosition = 0
                    editor.pressEnter(false, false, false, false)
                    rootNode.focusedWidget = rootNode.children[1]

                    rootNode.insertText(string: "Coucou", replacementRange: rootNode.selectedTextRange)

                    var insertedTree = """
                    TestCommands
                    \(String.tabs(1))- First bullet
                    \(String.tabs(1))- Coucou
                    \(String.tabs(1))- Second bullet

                    """
                    expect(rootNode.printTree()).to(equal(insertedTree))
                    editor.undo(String("Undo"))
                    editor.undo(String("Undo"))

                    expect(rootNode.printTree()).to(equal(tree))

                    rootNode.cursorPosition = 6
                    editor.pressEnter(false, false, false, false)

                    insertedTree = """
                    TestCommands
                    \(String.tabs(1))- First bullet
                    \(String.tabs(1))- Second
                    \(String.tabs(1))-  bullet

                    """
                    expect(rootNode.printTree()).to(equal(insertedTree))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))

                    rootNode.cursorPosition = 13
                    editor.pressEnter(false, false, false, false)
                    rootNode.focusedWidget = rootNode.children[2]

                    rootNode.insertText(string: "Coucou", replacementRange: rootNode.selectedTextRange)

                    insertedTree = """
                    TestCommands
                    \(String.tabs(1))- First bullet
                    \(String.tabs(1))- Second bullet
                    \(String.tabs(1))- Coucou

                    """

                    expect(rootNode.printTree()).to(equal(insertedTree))
                    editor.undo(String("Undo"))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }
            }
        }

        describe("Delete Commands") {
            beforeEach {
                BeamNote.clearCancellables()
                let note = self.setupTree()
                let bullet2 = BeamElement("Second bullet")
                note.addChild(bullet2)
                editor = BeamTextEdit(root: note, journalMode: true)
                editor.prepareRoot()
                rootNode = editor.rootNode!

                tree = """
                TestCommands
                \(String.tabs(1))- First bullet
                \(String.tabs(1))- Second bullet

                """

                expect(rootNode.printTree()).to(equal(tree))
            }
            afterEach {
                BeamNote.clearCancellables()
            }
            context("Not Indented") {
                it("deletes node backward") {
                    rootNode.focusedWidget = rootNode.children[1]
                    rootNode.cursorPosition = 0
                    rootNode.deleteBackward()

                    let deletedBackwardTree = """
                    TestCommands
                    \(String.tabs(1))- First bulletSecond bullet

                    """
                    expect(rootNode.printTree()).to(equal(deletedBackwardTree))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }
                it("deletes node forward") {
                    rootNode.focusedWidget = rootNode.children[0]
                    rootNode.cursorPosition = 12
                    rootNode.deleteForward()

                    let deletedForwardTree = """
                    TestCommands
                    \(String.tabs(1))- First bulletSecond bullet

                    """
                    expect(rootNode.printTree()).to(equal(deletedForwardTree))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }

                it("deletes a selection of nodes") {
                    rootNode.focusedWidget = rootNode.children[0]
                    _ = rootNode.startNodeSelection()
                    rootNode.extendNodeSelectionDown()
                    expect(rootNode.state.nodeSelection?.nodes.count).to(equal(2))
                    rootNode.deleteBackward()
                    rootNode.focusedWidget = rootNode.children[0]
                    rootNode.insertText(string: "Coucou", replacementRange: rootNode.selectedTextRange)

                    let deletedTree = """
                    TestCommands
                    \(String.tabs(1))- Coucou

                    """
                    expect(rootNode.printTree()).to(equal(deletedTree))
                    editor.undo(String("Undo"))
                    editor.undo(String("Undo"))
                    expect(rootNode.printTree()).to(equal(tree))
                }

            }
        }
    }

    private func setupTree() -> BeamNote {
        BeamTestsHelper.logout()

        DocumentManager().deleteAll() { result in
            DispatchQueue.main.async {

                switch result {
                case .failure(let error):
                    // TODO: i18n
                    XCTFail("Could not delete documents \(error)")
                case .success:
                    break
                }
            }
        }

        BeamNote.clearCancellables()
        let note = BeamNote.fetchOrCreate(title: "TestCommands")

        let bullet1 = BeamElement("First bullet")
        note.addChild(bullet1)

        return note
    }
}
