//
//  NoteViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class NoteViewTests: XCTestCase {
    
    let todayNoteNameCreationViewFormat = DateHelper().getTodaysDateString(.noteViewCreation)
    let todayNoteNameTitleViewFormat = DateHelper().getTodaysDateString(.noteViewTitle)
    let todayNoteNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.noteViewCreationNoZeros)


    func testForPerformance() {
        XCUIApplication().launch()
        let journalView = JournalTestView()

        let omnibox = OmniBoxTestView()
        omnibox.searchInOmniBox("Beam", true)

        let noteView = NoteTestView()

        noteView.waitForNoteViewToLoad()
        sleep(2)
        let text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

        noteView.typeInNoteNodeByIndex(noteIndex: 0, text: text)

        sleep(2)
        AllNotesTestView().openJournal()
//        ShortcutsHelper().shortcutActionInvoke(action: .showJournal)


    }

//    func SKIPtestDefaultNoteView() throws {
//        try XCTSkipIf(true, "Workaround to open a note from journal/all notes menu is pending")
//        let defaultNumberOfNotesAtFreshInstallation = 1
//        let journalView = launchApp()
//        var noteView: NoteTestView?
//        var allNotesView: AllNotesTestView?
//        
//        step("Given I open All Notes view"){
//            allNotesView = journalView.openAllNotesMenu()
//        }
//        
//        step("Then number of notes available by default is \(defaultNumberOfNotesAtFreshInstallation)"){
//            XCTAssertEqual(defaultNumberOfNotesAtFreshInstallation, allNotesView!.getNumberOfNotes())
//        }
//        
//        let todaysDateInNoteTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
//        let todaysDateInNoteCreationDateFormat = DateHelper().getTodaysDateString(.noteViewCreation)
//        step("When I open \(todaysDateInNoteTitleFormat) from All notes view"){
//            noteView = allNotesView!.openJournal()
//                .openNoteFromAllNotesList(noteTitleToOpen: todaysDateInNoteTitleFormat)
//        }
//
//        step("Then the title of the note is \(todaysDateInNoteTitleFormat) and its creation date is \(todaysDateInNoteCreationDateFormat)"){
//            noteView!.waitForNoteViewToLoad()
//            let noteTitle = noteView!.getNoteTitle()
//            XCTAssertTrue(noteTitle == todayNoteNameTitleViewFormat || noteTitle == todayNoteNameCreationViewFormat || noteTitle == todayNoteNameCreationViewFormatWithout0InDays)
//            XCTAssertTrue(noteView!.staticText(NoteViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
//            XCTAssertTrue(noteView!.staticText(todaysDateInNoteCreationDateFormat).exists)
//            XCTAssertTrue(noteView!.image(NoteViewLocators.Buttons.deleteNoteButton.accessibilityIdentifier).exists)
//            XCTAssertTrue(noteView!.image(NoteViewLocators.Buttons.publishNoteButton.accessibilityIdentifier).exists)
//            XCTAssertTrue(noteView!.staticText(todaysDateInNoteTitleFormat).exists)
//        }
//        
//        let defaultNotesCount = 1
//        step("Then number of notes available by default is \(defaultNotesCount) and it is empty"){
//            let notes = noteView!.getNoteNodesForVisiblePart()
//            XCTAssertEqual(notes.count, defaultNotesCount)
//            XCTAssertEqual(notes.first?.value as! String, emptyString)
//        }
//
//    }
}
