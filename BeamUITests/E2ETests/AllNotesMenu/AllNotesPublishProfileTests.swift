//
//  AllNotesPublishProfileTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 07.06.2022.
//

import Foundation
import XCTest

class AllNotesPublishProfileTests: BaseTest {
    
    let allNotes = AllNotesTestView()
    let noteName1 = "First published"
    let noteName2 = "Second published"
    
    override func setUp() {
        step("GIVEN I sign up") {
            super.setUp()
            signUpStagingWithRandomAccount()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
        }
    }
    
    private func assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues) {
        let actualValues = allNotes.getAllSortingCounterValues().sortingCounterValues!
        let result = actualValues.isEqualTo(expectedValues)
        XCTAssertTrue(result.0, result.1)
    }
    
    func testCreatePublishedAndUnpublishNote() {
        testrailId("C709")
        step("THEN by default the All notes counter values are correct") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 4, privat: 4, published: 0, publishedProfile: 0))
        }
        
        testrailId("C734")
        step("WHEN I open Published Notes") {
            allNotes
                .openTableView(.publishedNotes)
        }
        
        step("THEN I see an empty table by default") {
            XCTAssertEqual(AllNotesTestTable().numberOfVisibleItems, 0)
        }
        
        step("WHEN I create First published note") {
            XCTAssertTrue(allNotes
                .typeCardNameAndClickAddFor(sortType: .newFirstPublishedNote, noteName: noteName1)
                .waitForPublishingProcessToStartAndFinishFor(noteName1), "Publishing timed out")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN the sorting counters for Published and All notes are increased, Private and On Profile remain the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 5, privat: 4, published: 1, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }

        step("WHEN I create Second published note") {
            XCTAssertTrue(allNotes
                .typeCardNameAndClickAddFor(sortType: .newPublishedNote, noteName: noteName2)
                .waitForPublishingProcessToStartAndFinishFor(noteName2), "Publishing timed out")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN the sorting counters for Published and All notes are increased, Private and On Profile remain the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        
        testrailId("C714")
        step("THEN I unpublish the note and it is gone from the list on Published") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.unpublish).waitForNotesNumberEqualTo(1), "The notes count didn't change after unpublishing")
            
            XCTAssertFalse(allNotes.isNoteNameAvailable(noteName2), "Unpublished \(noteName2) note persists in the list")
        }
        
        step("THEN the sorting counters for Published and All notes are decreased, Private is increased and On Profile remains the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 5, published: 1, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        
        testrailId("C1031")
        step("WHEN I open a published note and tick Add to Profile") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.publishOnProfile).waitForNotesNumberEqualTo(1), "The notes count changed after Adding to Profile")
            sleep(3) // wait for note to be published on profile
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN Add to Profile sorting counter is increased and other counters remain the same and ") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 5, published: 1, publishedProfile: 1))
        }
    }
    
    func testCreatePublishedOnProfileNoteAndRemoveFromProfileNote() {
        testrailId("C710, C735")
        step("WHEN I open Published on Profile Notes") {
            allNotes
                .openTableView(.profileNotes)
        }
        
        step("THEN I see an empty table by default") {
            XCTAssertEqual(AllNotesTestTable().numberOfVisibleItems, 0)
        }
        
        step("WHEN I create First published on Profile note") {
            XCTAssertTrue(allNotes.typeCardNameAndClickAddFor(sortType: .newFirstPublishedProfileNote, noteName: noteName1).waitForPublishingProcessToStartAndFinishFor(noteName1), "Publishing timed out")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN all sorting counters are increased, apart from Private") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 5, privat: 4, published: 1, publishedProfile: 1))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }

        step("WHEN I create second published on Profile note") {
            XCTAssertTrue(allNotes
                .typeCardNameAndClickAddFor(sortType: .newPublishedProfileNote, noteName: noteName2)
                .waitForPublishingProcessToStartAndFinishFor(noteName1), "Publishing timed out")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN all sorting counters are increased, apart from Private") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 2))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        
        testrailId("C1032")
        step("THEN I \(noteName2) note is gone from the list on Unpublishing from profile") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.unpublishFromProfile).waitForNotesNumberEqualTo(1), "The notes count didn't change after removing from Profile")
            XCTAssertFalse(allNotes.isNoteNameAvailable(noteName2), "Removed from profile '\(noteName2)' note persists in the list")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN the sorting counters only for On Profile is decreased, but Published, All notes and Private remains the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 1))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
    }
    
    func testPublishPrivateNote() throws {
        try XCTSkipIf(isBigSurOS(), "issue that happens only on Big Sur - https://linear.app/beamapp/issue/BE-5098/note-is-removed-from-all-notes-table-on-publish-from-all-notes-on-big. Until issue is fixed -> it is skipped for Big Sur")
        testrailId("C713, C733")
        step("WHEN I open Private Notes") {
            allNotes
                .openTableView(.privateNotes)
        }
        
        step("THEN I see 4 notes default") {
            XCTAssertEqual(AllNotesTestTable().numberOfVisibleItems, 4)
        }
        
        step("WHEN I Publish first note") {
            let firstNoteTitle = allNotes.getNoteNameValueByIndex(0)
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.publish).waitForNotesNumberEqualTo(3), "The notes count didn't change after publishing the note")
            XCTAssertFalse(allNotes.isNoteNameAvailable(firstNoteTitle), "Removed from profile '\(firstNoteTitle)' note persists in the list")
        }
        
        testrailId("C732, C733, C734, C735")
        step("THEN all sorting counters remain the same, Private is increased and Published is decreased") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 4, privat: 3, published: 1, publishedProfile: 0))
        }
        
    }
}
