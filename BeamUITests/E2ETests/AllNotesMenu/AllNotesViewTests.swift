//
//  AllNotesViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllNotesViewTests: BaseTest {
    
    var allNotesView: AllNotesTestView!
    
    override func setUp() {
        step ("GIVEN I open All notes") {
            setupStaging(withRandomAccount: true)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
            allNotesView.waitForAllNotesViewToLoad()
        }
    }
    
    private func openAllNotesAndGetRowFor(noteTitle: String) -> RowAllNotesTestTable {
        //Open journal to trigger AllNotes updating (flakiness reproduced only on CI)
        shortcutHelper.shortcutActionInvoke(action: .showJournal)
        JournalTestView().waitForJournalViewToLoad()
        shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        allNotesView.waitForAllNotesViewToLoad()
        let row = AllNotesTestTable().rows
            .first(where: {$0.title == noteTitle})!
        return row
    }
    
    private func selectAllNodesAndDeleteContent(view: NoteTestView) {
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
        view.typeKeyboardKey(.delete)
    }
    
    private func openAndRemoveAllFrom(note: String) {
        let noteView = allNotesView.openNoteByName(noteTitle: note)
        //flakiness workaround to make shortcuts actions applicable
        noteView.waitForNoteViewToLoad()
        noteView.waitForNoteTitleToBeVisible()
        noteView.getNoteNodeElementByIndex(0).tapInTheMiddle()
        selectAllNodesAndDeleteContent(view: noteView)
        if noteView.getNumberOfVisibleNotes() > 1 {
            selectAllNodesAndDeleteContent(view: noteView)
        }
        noteView.waitForNoteViewToLoad()
    }
    
    func testCardRenamingApplyingInAllNotes() {
        
        let noteName = "Capture"
        
        step ("WHEN I rename the note") {
            let noteView = allNotesView.openNoteByName(noteTitle: noteName)
            noteView.waitForNoteViewToLoad()
            noteView.makeNoteTitleEditable()
            noteView.typeKeyboardKey(.delete, 4)
            noteView.typeKeyboardKey(.enter)
        }
        
        step ("THEN it is successfully renamed in All Notes") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
            allNotesView.waitForAllNotesViewToLoad()
            XCTAssertFalse(allNotesView.isNoteNameAvailable(noteName))
            XCTAssertTrue(allNotesView.isNoteNameAvailable("Cap"))
        }
    }
    
    //To be refactored once https://linear.app/beamapp/issue/BE-4401/all-notes-links-column-counts-backlinks-references-instead-of-just
    func testAllNotesLinksCounter() {
        
        let linkNoteName = "How to beam"
        let linkedNoteName = "Capture"
        
        step ("WHEN I remove links from \(linkNoteName)") {
            openAndRemoveAllFrom(note: linkNoteName)
        }
        
        step ("THEN links counter is updated correctly for \(linkedNoteName)") {
            let row = openAllNotesAndGetRowFor(noteTitle: linkedNoteName)
            XCTAssertEqual(row.links, 0)
        }
        
        step ("WHEN I create a link from \(linkNoteName) to \(linkedNoteName)") {
            let noteView = allNotesView.openNoteByName(noteTitle: linkNoteName)
            noteView.waitForNoteViewToLoad()
            noteView.waitForNoteTitleToBeVisible()
            noteView.createBiDiLink(linkedNoteName)
        }
        
        step ("THEN links counter is updated correctly for \(linkedNoteName)") {
            let row = openAllNotesAndGetRowFor(noteTitle: linkedNoteName)
            XCTAssertEqual(row.links, 1)
        }
    }
    
    //To be refactored with automatically published new note via https://linear.app/beamapp/issue/BE-4445/created-published-note-via-uitest-menu-is-not-recognized-as-published
    func testAllNotesURLCounter() {
        
        let rowIndex = 0
        
        step ("WHEN I publish first note") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
            allNotesView.waitForAllNotesViewToLoad()
            allNotesView
                .openMenuForSingleNote(rowIndex)
                .selectActionInMenu(.publish)
        }
        
        step ("THEN URL icon appears for the first note") {
            XCTAssertTrue(allNotesView.getURLiconElementFor(rowIndex: rowIndex).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step ("THEN Link copied icon appears on the icon click") {
            allNotesView.getURLiconElementFor(rowIndex: rowIndex).hoverAndTapInTheMiddle()
            XCTAssertTrue(allNotesView.app.staticTexts["Link Copied"].waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
    }
    
    func testAllNotesWordsCounter() {
        
        let noteName = "How to beam"
        let wordsToAdd = "Here are_the words to-add"
        
        step ("WHEN I remove words from \(noteName)") {
            openAndRemoveAllFrom(note: noteName)
        }
        
        step ("THEN words counter is updated correctly for \(noteName)") {
            let row = openAllNotesAndGetRowFor(noteTitle: noteName)
            XCTAssertEqual(row.words, 0)
        }
        
        step ("WHEN I type \(wordsToAdd) in a \(noteName)") {
            let noteView = allNotesView.openNoteByName(noteTitle: noteName)
            noteView.waitForNoteViewToLoad()
            noteView.typeInNoteNodeByIndex(noteIndex: 0, text: wordsToAdd, needsActivation: true)
        }
        
        step ("THEN words counter is updated correctly for \(noteName)") {
            let row = openAllNotesAndGetRowFor(noteTitle: noteName)
            XCTAssertEqual(row.words, 5)
        }
    }
    
    func testAllNotesUpdatedDateView() {
        
        let expectedDate = DateHelper().getTodaysDateString(.allNotesViewDates)
        
        step ("THEN by default the notes has correct today's '\(expectedDate)' date") {
            let tableRows = AllNotesTestTable().rows
            tableRows.forEach {
                XCTAssertEqual($0.updated, expectedDate)
            }
        }
    }
    
    func testShowDailyNotesFilter() throws {
        let tableBeforeFilterApplied = AllNotesTestTable()
        
        step ("WHEN I disable displaying of the Daily notes") {
            allNotesView.showDailyNotesClick()
                        .waitForAllNotesViewToLoad()
        }
        
        step ("THEN I don't see daily notes anymore in All Notes table") {
            let tableAfterFilterApplied = AllNotesTestTable()
            XCTAssertEqual(tableAfterFilterApplied.numberOfVisibleItems, 2)
            XCTAssertTrue(allNotesView.isNoteNameAvailable("How to beam"))
            XCTAssertTrue(allNotesView.isNoteNameAvailable("Capture"))
        }
        
        step ("WHEN I enable displaying of the Daily notes") {
            allNotesView.showDailyNotesClick()
                        .waitForAllNotesViewToLoad()
        }
        
        step ("THEN I see daily notes in All Notes table") {
            let tableAfterFilterEnabledAgain = AllNotesTestTable()
            let comparisonResult = tableAfterFilterEnabledAgain.isEqualTo(tableBeforeFilterApplied)
            XCTAssertTrue(comparisonResult.0, comparisonResult.1)
        }
    }
    
}
