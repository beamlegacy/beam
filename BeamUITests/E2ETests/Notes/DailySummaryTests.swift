//
//  DailySummaryTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 02/06/2022.
//

import Foundation
import XCTest
import SwiftUI

class DailySummaryTests: BaseTest {
    
    var journalView: JournalTestView!
    let noteView = NoteTestView()
    let allNotes = AllNotesTestView()
    let linkToOpen = "Pitchfork"
    let noteToOpen = "Triplego"
    let dummyText = "Dummy Text"
    let startedDailySummaryExpected = "Started Triplego, Laylow. Worked on Alpha Wann, Prince Waly and RA Electronic music online, Pitchfork"
    let continueOnDailySummaryExpected = "Continue on Key Glock, Maxo Kream and LeMonde, Twitter"
    
    override func setUp() {
        journalView = launchApp()

        step("Given I populate daily summary"){
            uiMenu.createFakeDailySummary()
            restartApp()
        }
    }
    
    private func verifyDailySummaryInView(){
        step("Then daily summary is displayed"){
            XCTAssertTrue(noteView.doesStartedDailySummaryExist())
            XCTAssertTrue(noteView.doesContinueOnDailySummaryExist())
        }

        step("And note contains Started daily summary sentence at second node"){
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(1), startedDailySummaryExpected)
        }

        step("And note contains Continue To daily summary sentence at third node"){
            XCTAssertEqual(noteView.getNoteNodeValueByIndex(2), continueOnDailySummaryExpected)
        }
        
    }
    
    private func verifyDailySummaryOpenLink(){
        step("When I open BiDi link Pitchfork"){
            noteView.openBiDiLink(linkToOpen)
            webView.waitForWebViewToLoad()
        }
        
        step("Then webview is opened"){
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)
        }
        
    }
    
    private func verifyDailySummaryOpenNote(){
        step("When I open BiDi link Triplego"){
            noteView.openBiDiLink(noteToOpen)
            noteView.waitForNoteViewToLoad()
        }
        
        step("Then note Triplego is opened"){
            XCTAssertEqual(noteView.getNoteTitle(), noteToOpen)
        }
        
    }
    
    func testDailySummaryInTodayNote() {
        testrailId("C804")
        let todaysDateInNoteTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        
        step("When I go to Today Note"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.openNoteByName(noteTitle: todaysDateInNoteTitleFormat)
        }
        
        verifyDailySummaryInView()
        
        verifyDailySummaryOpenNote()

        step("When I go to Today Note"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.openNoteByName(noteTitle: todaysDateInNoteTitleFormat)
        }
        
        verifyDailySummaryOpenLink()
    }
    
    func testDailySummaryInJournal() {
        testrailId("C804")
        verifyDailySummaryInView()
        
        verifyDailySummaryOpenNote()

        step("When I go back to Journal"){
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
        }
        
        verifyDailySummaryOpenLink()
    }
    
    func testNoBulletDragDropAllowedOnDailySummary() {
        testrailId("C804")
        step("When I open Journal"){
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
        }
        
        step("And I populate today's note with one text node") {
            journalView.typeInNoteNodeByIndex(noteIndex: 0, text: dummyText,  needsActivation: true)
        }
        
        step("And I drag the bullet down") {
            journalView.typeKeyboardKey(.downArrow)
            shortcutHelper.shortcutActionInvoke(action: .moveBulletDown)
        }
        
        step("Then it has not been inserted in Daily Summary") {
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(1), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(2), continueOnDailySummaryExpected)
        }
    }
    
    func testDailySummaryCannotBeDeleted() {
        testrailId("C804")
        step("When I open Journal"){
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
        }
        
        step("And I populate today's note with one text node") {
            journalView.typeInNoteNodeByIndex(noteIndex: 0, text: dummyText,  needsActivation: true)
            journalView.typeKeyboardKey(.enter)
            journalView.typeInNoteNodeByIndex(noteIndex: 1, text: dummyText,  needsActivation: true)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(1), dummyText)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(2), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(3), continueOnDailySummaryExpected)
        }
        
        step("Then daily summary is still at the bottom") {
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(1), dummyText)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(2), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(3), continueOnDailySummaryExpected)
        }
        
        step("When I delete all note content") {
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            journalView.typeKeyboardKey(.delete)
        }
        
        step("Then daily summary has not been deleted") {
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(0), emptyString)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(1), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getNoteNodeValueByIndex(2), continueOnDailySummaryExpected)
        }
    }
    
}
