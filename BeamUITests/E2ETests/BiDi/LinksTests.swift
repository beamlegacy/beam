//
//  Links.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class LinksTests: BaseTest {
    
    let noteName1 = "Test1"
    let noteName2 = "Test2"
    
    var noteView: NoteTestView!
    
    private func createNotesAndLinkThem() -> NoteTestView {
        let journalView = launchApp()
        step("Given I create 2 notes"){
            uiMenu.createAndOpenNote()
            noteView = journalView.createNoteViaOmniboxSearch(noteName2) //to be applied once https://linear.app/beamapp/issue/BE-4443/allow-typing-in-texteditor-of-the-note-created-via-uitest-menu is fixed
        }

        step("Then I link note 2 to note 1"){
            noteView.createBiDiLink(noteName1).openBiDiLink(0)
        }
        
        return noteView
    }
    
    func testCreateNoteLink()  {
        noteView = createNotesAndLinkThem()
        
        step("Then Note with links is correctly created"){
            noteView.waitForNoteTitleToBeVisible()
            noteView.waitForNoteViewToLoad()
            XCTAssertTrue(noteView.getLinksNames()[0].waitForExistence(timeout: BaseTest.implicitWaitTimeout), "Links names didn't appear during \(BaseTest.minimumWaitTimeout) timeout")
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            XCTAssertEqual(noteView.getLinksContentNumber(), 1)
            XCTAssertEqual(noteView.getLinkNameByIndex(0), noteName2)
            XCTAssertEqual(noteView.getLinkContentByIndex(0), noteName1 + " ") //looks like a bug
            noteView.assertLinksCounterTitle(expectedNumber: 1)
        }

        step("And I can navigate to a note by Link both sides"){
            noteView.openLinkByIndex(0)
            noteView.waitForNoteViewToLoad()
            XCTAssertEqual(noteView.getLinksNamesNumber(), 0)
            noteView.openBiDiLink(0)
            noteView.waitForNoteViewToLoad()
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            XCTAssertEqual(noteView.getLinkContentByIndex(0), noteName1 + " ")
        }

    }
    
    func testNoteLinkDeletion() {
        noteView = createNotesAndLinkThem()
        
        step("When I delete the link between \(noteName2) and \(noteName1)"){
            noteView.getFirstLinksContentElement().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .selectAll)
            noteView.typeKeyboardKey(.delete)
        }

        step("When I open \(noteName2)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
        }
        
        step("Then note 2 has no links available"){
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString)
        }
        
        step("Given I open \(noteName1) and I link \(noteName2)"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            noteView.createBiDiLink(noteName2)
        }

        step("Given I refresh the view switching notes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
        }

        step("When I delete the link between \(noteName2) and \(noteName1)"){
            noteView.getNoteNodeElementByIndex(0).tapInTheMiddle()
            noteView.typeKeyboardKey(.leftArrow)
            noteView.typeKeyboardKey(.delete)
        }

        step("Then note 2 has no links available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString)
        }
        
        step("Given I link \(noteName1) and I link \(noteName2)"){
            noteView.createBiDiLink(noteName1)
        }
        
        step("Given I refresh the view switching notes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
        }
        
        step("When I delete note 1"){
            noteView.clickDeleteButton().confirmDeletion()
        }
        
        step("Then note 2 has no links available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertTrue(noteView.waitForNoteToOpen(noteTitle: noteName1), "\(noteName1) note is failed to load")
            XCTAssertEqual(noteView.getLinksNamesNumber(), 0)
        }

    }
    
    func testNoteLinkTitleEditing() throws {
        let textToType = " some text"
        let renamingErrorHandling = " Some Text"
        noteView = createNotesAndLinkThem()
        
        step("When I change \(noteName1) name to \(noteName1)\(textToType)"){
            noteView.makeNoteTitleEditable().typeText(textToType)
            noteView.typeKeyboardKey(.enter)
        }

        let expectedEditedName1 = noteName1 + textToType + " "

        step("Then note name changes are applied in links for note 1"){
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            XCTAssertEqual(noteView.getLinksContentNumber(), 1)
            XCTAssertEqual(noteView.getLinkNameByIndex(0), noteName2)
            XCTAssertTrue(waitForStringValueEqual(expectedEditedName1, noteView.getLinkContentElementByIndex(0), TimeInterval(2)), "\(noteView.getLinkContentByIndex(0)) is not equal to \(expectedEditedName1)")
        }
       
        step("And note name changes are applied for note 2 note"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 1)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), expectedEditedName1)
        }

        step("When I change \(noteName2) name to \(noteName2)\(textToType)"){
            noteView.makeNoteTitleEditable().typeText(textToType)
            noteView.typeKeyboardKey(.enter)
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1 + textToType)
        }

        step("Then note name changes are applied in links for note 1"){
            XCTAssertEqual(noteView.getLinksNamesNumber(), 1)
            XCTAssertEqual(noteView.getLinksContentNumber(), 1)
            XCTAssertEqual(noteView.getLinkNameByIndex(0), noteName2 + renamingErrorHandling)
            XCTAssertEqual(noteView.getLinkContentByIndex(0), expectedEditedName1)
        }

    }
    
    func testLinksSectionBreadcrumbs() throws {
        noteView = createNotesAndLinkThem()
        let additionalNote = "Level1"
        let editedValue = "Level0"

        step("Then by default there is no breadcrumb available"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertFalse(noteView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

        step("When I create indentation level for the links"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2)
                .typeKeyboardKey(.upArrow)
            noteView.app.typeText(additionalNote)
            noteView.typeKeyboardKey(.enter)
            noteView.typeKeyboardKey(.tab)
        }

        step("Then the breadcrumb appears in links section"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertTrue(noteView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(noteView.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(noteView.getBreadCrumbTitleByIndex(0), additionalNote)
        }

        
        step("When I edit parent of indentation level"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2).getNoteNodeElementByIndex(0).tapInTheMiddle()
            noteView.typeKeyboardKey(.delete, 1)
            noteView.app.typeText("0")
        }

        step("Then breadcrumb title is changed in accordance to previous changes"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertTrue(noteView.waitForBreadcrumbs(), "Breadcrumbs didn't load/appear")
            XCTAssertEqual(noteView.getBreadCrumbElementsNumber(), 1)
            XCTAssertEqual(noteView.getBreadCrumbTitleByIndex(0), editedValue)
        }

        
        step("When delete indentation level"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName2).getNoteNodeElementByIndex(1).tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .beginOfLine)
            noteView.typeKeyboardKey(.delete)
            noteView.typeKeyboardKey(.space)
        }
        
        step("Then there are no breadcrumbs in links section"){
            noteView.openNoteFromAllNotesList(noteTitleToOpen: noteName1)
            XCTAssertFalse(noteView.waitForBreadcrumbs(), "Breadcrumbs are available though shouldn't be")
        }

    }
    
    func SKIPtestLinksIndentationLevels() throws {
        try XCTSkipIf(true, "WIP")
    }
    
}
