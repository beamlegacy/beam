//
//  NoteCreationTests.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class NoteCreationTests: BaseTest {
    
    let noteNameToBeCreated = "NoteCreation"
    let otherNoteNameToBeCreated = "OtherNoteCreation"
    let noteView = NoteTestView()
    let allNotesView = AllNotesTestView()
    var journalView: JournalTestView!
    
    override func setUp() {
        journalView = launchApp()
    }
    
    func testCreateNoteFromAllNotes() {
        testrailId("C708")
        step("Given I get number of notes in All Notes view"){
            waitFor(PredicateFormat.isHittable.rawValue,    journalView.button(ToolbarLocators.Buttons.noteSwitcherAllNotes.accessibilityIdentifier))
        }
        let numberOfNotesBeforeAdding = journalView.openAllNotesMenu().getNumberOfNotes()
        
        step("When I create a note from All Notes view"){
            allNotesView.addNewPrivateNote(noteNameToBeCreated)
            var timeout = 5 //temp solution while looking for an elegant way to wait
            repeat {
                if numberOfNotesBeforeAdding != allNotesView.getNumberOfNotes() {
                    return
                }
                sleep(1)
                timeout-=1
            } while timeout > 0
        }

        step("Then number of notes is increased to +1 in All Notes list"){
            XCTAssertEqual(numberOfNotesBeforeAdding + 1, allNotesView.getNumberOfNotes())
        }
    }
    
    func SKIPtestCreateNoteUsingNotesSearchList() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")

        step("When I create \(noteNameToBeCreated) a note from Webview notes search results"){
            let webView = journalView.searchInOmniBox(noteNameToBeCreated, true)
            webView.searchForNoteByTitle(noteNameToBeCreated)
            XCTAssertTrue(waitForStringValueEqual(noteNameToBeCreated, webView.getDestinationNoteElement()), "Destination note is not \(noteNameToBeCreated), but \(String(describing: webView.getDestinationNoteElement().value))")
            webView.openDestinationNote()
        }

        step("Then note with \(noteNameToBeCreated) is opened"){
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            XCTAssertTrue(noteView.textField(noteNameToBeCreated).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

    }
    
    func testCreateNoteUsingNoteReference() {
        testrailId("C746")
        step("When I create \(noteNameToBeCreated) a note referencing it from another Note"){
            journalView.textView(NoteViewLocators.TextFields.textNode.accessibilityIdentifier).firstMatch.clickOnExistence()
            journalView.app.typeText("@" + noteNameToBeCreated)
            journalView.typeKeyboardKey(.enter)
            journalView.app.typeText("[[" + otherNoteNameToBeCreated)
            journalView.typeKeyboardKey(.enter)
        }

        step("Then note with \(noteNameToBeCreated) name appears in All notes menu list"){
            let allNotesMenu = journalView.openAllNotesMenu()
            XCTAssertTrue(allNotesMenu.isNoteNameAvailable(noteNameToBeCreated))
            XCTAssertTrue(allNotesMenu.isNoteNameAvailable(otherNoteNameToBeCreated))
        }
    }
    
    func testCreateNoteOmniboxSearch() {
        testrailId("C745")
        step("When I create \(noteNameToBeCreated) a note from Omnibox search results"){
            journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        }
        
        step("Then note with \(noteNameToBeCreated) is opened"){
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            XCTAssertEqual(noteView.getNoteTitle(), noteNameToBeCreated)
        }

        step("Then Journal has no mentions for created note"){
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
            journalView.waitForJournalViewToLoad()
            XCTAssertEqual(noteView.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(0), emptyString )
        }

    }
    
    func testCreateNoteOmniboxOptionEnter() {
        testrailId("C745")
        step("When I create \(noteNameToBeCreated) a note from Omnibox search results via Option+Enter"){
            journalView.searchInOmniBox(noteNameToBeCreated, false)
            _ = OmniBoxTestView().getAutocompleteResults().firstMatch.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            journalView.app.typeKey("\r", modifierFlags: .option)
        }

        step("Then note with \(noteNameToBeCreated) is opened"){
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            XCTAssertEqual(noteView.getNoteTitle(), noteNameToBeCreated)
        }

    }
    
    func testCreateNoteViewIcon() {
        testrailId("C744")
        step("When I click New note icon") {
            noteView.clickNewNoteCreationButton().getOmniBoxSearchField().typeText(noteNameToBeCreated)
            noteView.typeKeyboardKey(.enter)
        }
        
        step("Then I can sucessfully create a note") {
            XCTAssertTrue(noteView.waitForNoteViewToLoad())
            XCTAssertEqual(noteView.getNoteTitle(), noteNameToBeCreated)
        }
    }
    
    func testCreateNoteUsingTextEditorKeywords() {
        testrailId("C1181")
        let keywords = ["YESterday", "today", "tOmorrow"]
        var index = -1
        var expectedNotesTitles = [String]()
        
        keywords.forEach { _ in
            expectedNotesTitles.append(DateHelper().getDateString(daysDifferenceFromToday: index, .noteViewTitle))
        }
        index = 0
        
        step("WHEN I create BiDi links using keywords:\(keywords.joined(separator: ","))") {
            keywords.forEach {
                journalView.typeInNoteNodeByIndex(noteIndex: index, text: "@\($0)", needsActivation: true)
                journalView.typeKeyboardKey(.enter, 2)
                index+=1
            }
            index = 0
        }
        
        step("THEN the note titles are correctly displayed in the text nodes") {
            for title in expectedNotesTitles {
                if (index == 1) { //to be removed once BE-5424 is fixed to assert all notes titles
                    XCTAssertEqual(noteView.getNoteNodeValueByIndex(index), title)
                }
            }
            index = 0
        }
        
        step("THEN Yesterday's and Tomorrow's notes are created, today's one remains by default") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView.waitForAllNotesViewToLoad()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 3)
            for title in expectedNotesTitles {
                XCTAssertTrue(allNotesView.isNoteNameAvailable(title))
            }
        }
    }
    
}
