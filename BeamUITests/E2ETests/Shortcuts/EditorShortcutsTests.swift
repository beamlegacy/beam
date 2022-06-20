//
//  EditorShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest
import BeamCore

class EditorShortcutsTests: BaseTest {
    
    var noteView: NoteTestView!
    
    func testInstantSearchFromNote() {
        let searchWord = "Everest"
        
        step ("Given I search for \(searchWord)"){
            launchApp()
            noteView = openFirstNoteInAllNotesList()
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: searchWord)
            shortcutHelper.shortcutActionInvoke(action: .instantSearch)
        }
        
        step ("Then I see 1 tab opened"){
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
            webView.openDestinationNote()
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
        }
        
        step ("Then I see \(searchWord) link as a first note"){
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 1)
            let actualNoteValue = noteView.getNoteNodeValueByIndex(0)
            XCTAssertTrue(actualNoteValue == searchWord + " - Google Search" ||
                          actualNoteValue == searchWord + " - Recherche Google" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)&client=safari" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)",
                          "Actual note value:\(actualNoteValue)")
            noteView.getNoteNodeElementByIndex(0).coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.5)).tap()
        }
        
        step ("Then I'm redirected to a new tab and the note has not been changed"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            webView.openDestinationNote()
            XCTAssertTrue(noteView!.waitForNoteViewToLoad())
            XCTAssertEqual(noteView!.getNumberOfVisibleNotes(), 1)
            let actualNoteValue = noteView.getNoteNodeValueByIndex(0)
            XCTAssertTrue(actualNoteValue == searchWord + " - Google Search" ||
                          actualNoteValue == searchWord + " - Recherche Google" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)&client=safari" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)")
        }
        
    }
    
    func testSelectAllCopyPasteUndoRedoTextInNote() {
        
        let textToType = "This text replaces selected notes text"
        step ("Then app doesn't crash after using text edit shortcuts on empty note"){
            launchApp()
            noteView = openFirstNoteInAllNotesList()
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            shortcutHelper.shortcutActionInvoke(action: .copy)
            noteView.typeKeyboardKey(.delete)
            shortcutHelper.shortcutActionInvoke(action: .undo)
            shortcutHelper.shortcutActionInvoke(action: .redo)
        }
        
        
        BeamUITestsHelper(noteView.app).tapCommand(.insertTextInCurrentNote)
        let firstNoteValue = noteView.getNoteNodeValueByIndex(1)
        
        shortcutHelper.shortcutActionInvoke(action: .selectAll)
        noteView.typeKeyboardKey(.delete)
        step ("Then deleted 1st note successfully"){
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), firstNoteValue)
        }
        
        step ("Then deleted all notes successfully"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            noteView.typeKeyboardKey(.delete)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: noteView!.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString)
            
        }
        
        step ("Then undo deletion successfully"){
            shortcutHelper.shortcutActionInvoke(action: .undo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), firstNoteValue)
            
        }
        
        step ("Then redo deletion successfully"){
            shortcutHelper.shortcutActionInvoke(action: .redo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString)
        }
        
        step ("Then undo redone successfully"){
            shortcutHelper.shortcutActionInvoke(action: .undo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), firstNoteValue)
        }
        
        step ("Then replace existing text"){
            noteView.getNoteNodeElementByIndex(0).tapInTheMiddle()
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: textToType)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), textToType)
            
        }
        
        step ("Then copy paste existing text"){
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            shortcutHelper.shortcutActionInvoke(action: .copy)
            noteView.typeKeyboardKey(.rightArrow)
            noteView.typeKeyboardKey(.return)
            noteView.pasteText(textToPaste: textToType)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 2, elementQuery: noteView.getNoteElementsQueryForVisiblePart()))
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), textToType)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(1), textToType)
        }
    }
    
    func SKIPtestSwitchWebToDestinationNote () throws {
        try XCTSkipIf(true, "WIP")
        let note1 = "Destination One"
        let note2 = "Destination Two"
        let testHelper = BeamUITestsHelper(webView.app)
        let journalView = launchApp()
        step ("Given I create \(note1) note"){
            //TBD replace creation by omnibox to craetion by Destination notes search
            webView.searchForNoteByTitle(note1)
            journalView.createNoteViaOmniboxSearch(note1)
        }
        
        step ("When I search in web and switch to note view"){
            journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step ("Then the destination note is remained \(note1)"){
            XCTAssertEqual(noteView!.getNoteTitle(), note1)
        }
        
        step ("Given I create \(note2) note"){
            journalView.createNoteViaOmniboxSearch(note2)
        }
        
        step ("When I search in web and switch to note view"){
            journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step ("Then the destination note is remained \(note2)"){
            XCTAssertEqual(noteView.getNoteTitle(), note2)
        }
        
        step ("Then \(note2) is a destination note in web mode"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            XCTAssertEqual(webView.getDestinationNoteTitle(), note2)
        }
        
        step ("Then \(note1) is a destination note in web mode when switching tabs"){
            shortcutHelper.shortcutActionInvoke(action: .jumpToPreviousTab)
            XCTAssertTrue(waitForStringValueEqual(note1, webView.getDestinationNoteElement(), BaseTest.minimumWaitTimeout))
        }
        
        step ("Then \(note2) is a destination note in web mode when switching tabs"){
            shortcutHelper.shortcutActionInvoke(action: .jumpToNextTab)
            XCTAssertTrue(waitForStringValueEqual(note2, webView.getDestinationNoteElement(), BaseTest.minimumWaitTimeout))
        }
       
    }
    
    func assertDestinationNote(_ noteName: String) {
        XCTAssertTrue(waitForStringValueEqual(noteName, webView.getDestinationNoteElement()), "Destination note is not \(noteName), but \(String(describing: webView.getDestinationNoteElement().value))")
    }
}
