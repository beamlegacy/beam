//
//  NoteViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class NoteViewTests: BaseTest {
    
    let todayNoteNameCreationViewFormat = DateHelper().getTodaysDateString(.noteViewCreation)
    let todayNoteNameTitleViewFormat = DateHelper().getTodaysDateString(.noteViewTitle)
    let todayNoteNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.noteViewCreationNoZeros)
    
    func SKIPtestDefaultNoteView() throws {
        try XCTSkipIf(true, "Workaround to open a note from journal/all notes menu is pending")
        let defaultNumberOfNotesAtFreshInstallation = 1
        let journalView = launchApp()
        var noteView: NoteTestView?
        var allNotesView: AllNotesTestView?
        
        step("Given I open All Notes view"){
            allNotesView = journalView.openAllNotesMenu()
        }
        
        step("Then number of notes available by default is \(defaultNumberOfNotesAtFreshInstallation)"){
            XCTAssertEqual(defaultNumberOfNotesAtFreshInstallation, allNotesView!.getNumberOfNotes())
        }
        
        let todaysDateInNoteTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        let todaysDateInNoteCreationDateFormat = DateHelper().getTodaysDateString(.noteViewCreation)
        step("When I open \(todaysDateInNoteTitleFormat) from All notes view"){
            noteView = allNotesView!.openJournal()
                .openNoteFromAllNotesList(noteTitleToOpen: todaysDateInNoteTitleFormat)
        }

        step("Then the title of the note is \(todaysDateInNoteTitleFormat) and its creation date is \(todaysDateInNoteCreationDateFormat)"){
            noteView!.waitForNoteViewToLoad()
            let noteTitle = noteView!.getNoteTitle()
            XCTAssertTrue(noteTitle == todayNoteNameTitleViewFormat || noteTitle == todayNoteNameCreationViewFormat || noteTitle == todayNoteNameCreationViewFormatWithout0InDays)
            XCTAssertTrue(noteView!.staticText(NoteViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(noteView!.staticText(todaysDateInNoteCreationDateFormat).exists)
            XCTAssertTrue(noteView!.image(NoteViewLocators.Buttons.deleteNoteButton.accessibilityIdentifier).exists)
            XCTAssertTrue(noteView!.image(NoteViewLocators.Buttons.publishNoteButton.accessibilityIdentifier).exists)
            XCTAssertTrue(noteView!.staticText(todaysDateInNoteTitleFormat).exists)
        }
        
        let defaultNotesCount = 1
        step("Then number of notes available by default is \(defaultNotesCount) and it is empty"){
            let notes = noteView!.getNoteNodesForVisiblePart()
            XCTAssertEqual(notes.count, defaultNotesCount)
            XCTAssertEqual(notes.first?.value as! String, emptyString)
        }

    }
}
