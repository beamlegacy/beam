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
            setupStaging(withRandomAccount: true)
            _ = webView.waitForWebViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
        }
    }
    
    private func assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues) {
        let actualValues = allNotes.getAllSortingCounterValues().sortingCournterValues!
        let result = actualValues.isEqualTo(expectedValues)
        XCTAssertTrue(result.0, result.1)
    }
    
    func testCreatePublishedAndUnpublishNote() {
        
        step("THEN by default the All notes counter values are correct") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 4, privat: 4, published: 0, publishedProfile: 0))
        }
        
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
        
        step("THEN the sorting counters for Published and All notes are increased, Private and On Profile remain the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 5, privat: 4, published: 1, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }

        step("WHEN I create Second published note") {
            XCTAssertTrue(allNotes
                .typeCardNameAndClickAddFor(sortType: .newPublishedNote, noteName: noteName2)
                .waitForPublishingProcessToStartAndFinishFor(noteName2), "Publishing timed out")
        }
        
        step("THEN the sorting counters for Published and All notes are increased, Private and On Profile remain the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        
        step("THEN I unpublish the note is gone from the list on Unpublishing") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.unpublish).waitForNotesNumberEqualTo(1), "The notes count didn't change after unpublishing")
            
            XCTAssertFalse(allNotes.isNoteNameAvailable(noteName2), "Unpublished \(noteName2) note persists in the list")
        }
        
        step("THEN the sorting counters for Published and All notes are decreased, Private is increased and On Profile remains the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 5, published: 1, publishedProfile: 0))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        
        step("WHEN I open a published note and tick Add to Profile") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.publishOnProfile).waitForNotesNumberEqualTo(1), "The notes count changed after Adding to Profile")
            sleep(2) // wait for note to be published on profile
        }
        
        step("THEN Add to Profile sorting counter is increased and other counters remain the same and ") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 5, published: 1, publishedProfile: 1))
        }
    }
    
    func testCreatePublishedOnProfileNoteAndRemoveFromProfileNote() {
        
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
        
        step("THEN all sorting counters are increased, apart from Private") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 5, privat: 4, published: 1, publishedProfile: 1))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }

        step("WHEN I create second published on Profile note") {
            XCTAssertTrue(allNotes
                .typeCardNameAndClickAddFor(sortType: .newPublishedProfileNote, noteName: noteName2)
                .waitForPublishingProcessToStartAndFinishFor(noteName1), "Publishing timed out")
        }
        
        step("THEN all sorting counters are increased, apart from Private") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 2))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
        

        step("THEN I \(noteName2) note is gone from the list on Unpublishing from profile") {
            XCTAssertTrue(allNotes
                .openMenuForSingleNote(0)
                .selectActionInMenu(.unpublishFromProfile).waitForNotesNumberEqualTo(1), "The notes count didn't change after removing from Profile")
            XCTAssertFalse(allNotes.isNoteNameAvailable(noteName2), "Removed from profile '\(noteName2)' note persists in the list")
        }
        
        step("THEN the sorting counters only for On Profile is decreased, but Published, All notes and Private remains the same") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 6, privat: 4, published: 2, publishedProfile: 1))
            allNotes.typeKeyboardKey(.escape) //to close the drop-down
        }
    }
    
    func testPublishPrivateNote() {
        
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
        
        step("THEN all sorting counters remain the same, Private is increased and Published is decreased") {
            assertSortingCounterValues(expectedValues: AllNotesTestView.SortingCounterValues(all: 4, privat: 3, published: 1, publishedProfile: 0))
        }
        
    }
}
