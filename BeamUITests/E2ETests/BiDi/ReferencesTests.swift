//
//  References.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class ReferencesTests: BaseTest {
    
    let noteName1 = "Test1"
    let noteName2 = "Test2"
    var noteView: NoteTestView!

    private func createNotesAndReferenceThem() -> NoteTestView {
        let journalView = launchApp()
        
        step ("GIVEN I create 2 notes"){
            uiMenu.createAndOpenNote()
            noteView = journalView.createNoteViaOmniboxSearch(noteName2) //to be applied once https://linear.app/beamapp/issue/BE-4443/allow-typing-in-texteditor-of-the-note-created-via-uitest-menu is fixed
        }

        step ("WHEN I reference note 2 to note 1"){
            noteView.createReference(noteName1)
        }
        
        return noteView
    }
    

    func testCreateNoteReference() {
        testrailId("C793")
        noteView = createNotesAndReferenceThem()
        
        step("WHEN I open \(noteName1) note") {
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
        }

        step("THEN references and links counter are correct") {
            XCTAssertEqual(noteView.getLinksNamesNumber(), 0) //Link ONLY
            XCTAssertEqual(noteView.getLinksContentNumber(), 0)
            noteView.assertReferenceCounterTitle(expectedNumber: 1)
        }
        
        testrailId("C806")
        step("WHEN I expand reference section") {
            noteView.expandReferenceSection()
        }
        
        testrailId("C800")
        step("THEN references and links counter are correct") {
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1) // Link and Reference
            XCTAssertEqual(noteView.getLinksContentNumber(), 1)
            XCTAssertEqual(noteView.getLinkNameByIndex(0), noteName2)
            XCTAssertEqual(noteView.getLinkContentByIndex(0), noteName1)
        }
        
        step ("Then I can navigate to a note by Reference to a source note"){
            noteView.openLinkByIndex(0)
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), noteName1)
        }
    }
    
    func testReferenceDeletion() {
        testrailId("C794")
        noteView = createNotesAndReferenceThem()
        noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            .expandReferenceSection()
        
        step ("When I delete the reference between \(noteName2) and \(noteName1)"){
            noteView.getFirstLinksContentElement().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            noteView.typeKeyboardKey(.delete)
        }

        step ("When I open \(noteName2)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
        }

        step ("Then note 2 has no references available"){
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString)
        }

        step ("Given I open \(noteName1) and I reference \(noteName2)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertFalse(noteView.doesReferenceSectionExist())
            noteView.createReference(noteName2)
        }

        step ("Given I refresh the view switching notes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
            XCTAssertTrue(noteView.doesReferenceSectionExist())
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
        }

        step ("When I delete the reference between \(noteName2) and \(noteName1)"){
            noteView.getNoteNodeElementByIndex(0).tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            noteView.typeKeyboardKey(.delete)
        }

        step ("Then note 2 has no references available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
            XCTAssertFalse(noteView.doesReferenceSectionExist())
        }

        step ("Given I reference \(noteName1) and I reference \(noteName2)"){
            noteView.createReference(noteName1)
        }

        step ("Given I refresh the view switching notes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertTrue(noteView.doesReferenceSectionExist())
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
        }

        step ("When I delete note 1"){
            noteView.clickDeleteButton().confirmDeletion()
        }
        
        step ("Then note 2 has no references available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertTrue(noteView.waitForNoteToOpen(noteTitle: noteName1), "\(noteName1) note is failed to load")
            XCTAssertFalse(noteView.doesReferenceSectionExist())
        }

    }
    
    func testReferenceEditing() {
        testrailId("C1042")
        let textToType = " some text"
        let renamedNote1 = noteName1 + textToType
        noteView = createNotesAndReferenceThem()
        uiMenu.resizeWindowLandscape()
        noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
        
        step ("Given I rename note 1 to \(noteName1)\(textToType)"){
            noteView.makeNoteTitleEditable().typeText(textToType)
            noteView.typeKeyboardKey(.enter)
        }

        step ("Then note 1 has no references available"){
            XCTAssertTrue(waitForDoesntExist(noteView.getRefereceSectionCounterElement()))
        }
        
        step ("Given I rename the note in note 2 to \(renamedNote1)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
                .getNoteNodeElementByIndex(0)
                .clickOnExistence()
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: textToType)
        }

        step ("Then in note 1 all the reference appears again"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: renamedNote1)
            XCTAssertTrue(noteView.doesReferenceSectionExist())
        }

        step ("When I change the reference text in note 1"){
            noteView.expandReferenceSection()
                .getLinkContentElementByIndex(0)
                .clickOnExistence()
            noteView.typeKeyboardKey(.delete, textToType.count)
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
        }

        step ("Then in note 2 the note is renamed as in note 1"){
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), noteName1)
        }

        step ("And in note 1 the reference is gone"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: renamedNote1)
            XCTAssertFalse(noteView.doesReferenceSectionExist())
        }

    }
    
    func testLinkReferecnes() throws {
        try XCTSkipIf(true, "Link and Link All buttons are not accessible, https://linear.app/beamapp/issue/BE-5217/link-single-reference-ui-tests")
        let secondReference = "\(noteName1) second REF"
        let thirdReference = "\(noteName1) THIRD_reference"
        noteView = createNotesAndReferenceThem()
        
        step ("Given I create reference \(secondReference) for note 2 and \(thirdReference) for note 3"){
            noteView.typeInNoteNodeByIndex(noteIndex: 1, text: secondReference)
            noteView.typeKeyboardKey(.enter)
            noteView.typeInNoteNodeByIndex(noteIndex: 2, text: thirdReference)
        }

        step ("Given I open \(noteName1)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            noteView.expandReferenceSection()
        }

        /*step ("When I click Link first reference"){
            
        }
        TBD once link button is accessible
        
        step ("Then "){
            
        }*/
             
        testrailId("C796")
        step ("When I click Link All for remained references"){
            noteView.expandReferenceSection()
                .linkAllReferences()
        }

        step ("Then the note has no references available"){
            XCTAssertTrue(waitForDoesntExist(noteView.getRefereceSectionCounterElement()))
        }
    }
    
    func testReferencesSectionBreadcrumbs() throws {
        testrailId("C802")
        noteView = createNotesAndReferenceThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        step ("Then by default there is no breadcrumb available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
                .expandReferenceSection()
            XCTAssertFalse(noteView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

        testrailId("C801")
        step ("When I create indentation level for the reference"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
                .typeKeyboardKey(.upArrow)
            noteView.app.typeText(additionalNote)
            noteView.typeKeyboardKey(.enter)
            noteView.typeKeyboardKey(.tab)
        }

        step ("Then the breadcrumb appears in references section"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
                .expandReferenceSection()
            XCTAssertTrue(noteView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(noteView.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(noteView.getBreadCrumbTitleByIndex(0), additionalNote)
        }

        step ("When I edit parent of indentation level"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2).getNoteNodeElementByIndex(0).tapInTheMiddle()
            noteView.typeKeyboardKey(.delete, 1)
            noteView.app.typeText("0")
        }

        step ("Then breadcrumb title is changed in accordance to previous changes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
                .expandReferenceSection()
            XCTAssertTrue(noteView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(noteView.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(noteView.getBreadCrumbTitleByIndex(0), editedValue)
        }

        step ("When delete indentation level"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2).getNoteNodeElementByIndex(1).tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .beginOfLine)
            noteView.typeKeyboardKey(.delete)
            noteView.typeKeyboardKey(.space)
        }

        step ("Then there are no breadcrumbs in reference section"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
                .expandReferenceSection()
            XCTAssertFalse(noteView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }
    }
    
    func testReferencesIndentationLevels() throws {
        try XCTSkipIf(true, "https://linear.app/beamapp/issue/BE-5218/testreferencesindentationlevels-ui-test")
    }
}
