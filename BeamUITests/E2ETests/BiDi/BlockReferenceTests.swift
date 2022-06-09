//
//  BlockReference.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class BlockReferenceTests: BaseTest {
    
    let noteName1 = "Block 1"
    let noteName2 = "Block 2"
    var noteView = NoteTestView()
    var noteForReference: String?
    
    func SKIPtestCreateBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()

        step("Given I create I create a block reference"){
            noteForReference = createBlockRefForTwoNotes(journalView, noteName1, noteName2)
        }

        step("Then it has correct number and content"){
            XCTAssertEqual(noteView.getNumberOfBlockRefs(), 1)
            XCTAssertEqual(noteView.getElementStringValue(element:  noteView.getBlockRefByIndex(0)), noteForReference!)
        }

    }
    
    func SKIPtestLockUnlockBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        let textToAdd = " additional text"
        step("Given I create I create a block reference"){
            noteForReference = createBlockRefForTwoNotes(journalView, noteName1, noteName2)
        }
        
        let blockRef = noteView.getBlockRefByIndex(0)
        step("Then the block reference is locked by default"){
            blockRef.tapInTheMiddle()
            blockRef.doubleClick() //Double click is just for sure the field is not editable
            XCTAssertTrue(waitForKeyboardUnfocus(blockRef))
        }

        step("When I unlock the block reference"){
            noteView.blockReferenceMenuActionTrigger(.blockRefUnlock, blockRefNumber: 1)
        }
        
        step("Then it can be changed"){
            blockRef.tapInTheMiddle()
            XCTAssertTrue(waitForKeyboardFocus(blockRef))
            blockRef.typeText("\(textToAdd)\r")
            XCTAssertEqual(noteView.getElementStringValue(element: blockRef), noteForReference! + textToAdd)
            noteView.typeKeyboardKey(.delete, textToAdd.count)
            XCTAssertEqual(noteView.getElementStringValue(element: blockRef), noteForReference!)
        }
    }
    
    func SKIPtestViewBlockReferenceOrigin() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        step("Given I create 2 notes"){
            createBlockRefForTwoNotes(journalView, noteName1, noteName2)
        }

        step("Then I can see correct origin of the reference"){
            noteView.blockReferenceMenuActionTrigger(.blockRefOrigin, blockRefNumber: 1)
            XCTAssertTrue(waitForStringValueEqual(noteName1, noteView.noteTitle), "Actual note name is \(noteView.noteTitle)")
        }

    }
    
    func SKIPtestRemoveBlockReference() throws {
        try XCTSkipIf(true, "Feature is temporary deprecated")
        let journalView = launchApp()
        
        step("Given I create 2 notes"){
            noteForReference = createBlockRefForTwoNotes(journalView, noteName1, noteName2)
        }

        step("Then I can successfully remove it"){
            noteView.blockReferenceMenuActionTrigger(.blockRefRemove, blockRefNumber: 1)
            XCTAssertTrue(waitForDoesntExist( noteView.textView(NoteViewLocators.TextViews.blockReference.accessibilityIdentifier)))
        }

        step("Then removing block reference doesn't remove the source text"){
            journalView.openRecentNoteByName(noteName2)
            let currentSourceNote = noteView.getElementStringValue(element:  noteView.getNoteNodesForVisiblePart()[1])
            XCTAssertEqual(currentSourceNote, noteForReference!)
        }

    }
    
    @discardableResult
    func createBlockRefForTwoNotes(_ view: JournalTestView, _ noteName1: String, _ noteName2: String) -> String {
        view.createNoteViaOmniboxSearch(noteName1)
        view.createNoteViaOmniboxSearch(noteName2)
        let helper = BeamUITestsHelper(view.app)
        helper.tapCommand(.insertTextInCurrentNote)
        
        let noteForReference = noteView.getElementStringValue(element:noteView.getNoteNodesForVisiblePart()[1])
        let referencePart = (noteForReference.substring(from: 0, to: 6))
        
        view.openRecentNoteByName(noteName1)
        noteView.addTestRef(referencePart)
        return noteForReference
    }
}
