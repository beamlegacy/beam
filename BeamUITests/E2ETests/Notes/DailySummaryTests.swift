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
    
    var noteView: NoteTestView!
    var journalView: JournalTestView!
    var helper: BeamUITestsHelper!
    let allNotes = AllNotesTestView()
    let linkToOpen = "Pitchfork"
    let pitchForkUrl = "pitchfork.com/contact/"
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
    
    private func verifyDailySummaryInView(view: TextEditorContextTestView){
        step("Then daily summary is displayed"){
            XCTAssertTrue(view.doesStartedDailySummaryExist())
            XCTAssertTrue(view.doesContinueOnDailySummaryExist())
        }

        step("And note contains Started daily summary sentence at second node"){
            XCTAssertEqual(view.getNoteNodeValueByIndex(1), startedDailySummaryExpected)
        }

        step("And note contains Continue To daily summary sentence at third node"){
            XCTAssertEqual(view.getNoteNodeValueByIndex(2), continueOnDailySummaryExpected)
        }
        
        step("When I open BiDi link Pitchfork"){
            view.openBiDiLink(linkToOpen)
            _ = webView.waitForWebViewToLoad()
        }
        
        step("Then the webview is opened and Pitchfork is searched"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), pitchForkUrl)
        }
        
        step("When I switch back to my note"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            XCTAssertTrue(view.doesStartedDailySummaryExist())
            XCTAssertTrue(view.doesContinueOnDailySummaryExist())
        }
        
        step("And I open BiDi link Triplego"){
            noteView = view.openBiDiLink(noteToOpen)
            noteView.waitForNoteViewToLoad()
        }
        
        step("Then note Triplego is opened"){
            XCTAssertEqual(noteView.getNoteTitle(), noteToOpen)
        }
        
        step("And daily summary is not displayed"){
            XCTAssertFalse(noteView.doesStartedDailySummaryExist())
            XCTAssertFalse(noteView.doesContinueOnDailySummaryExist())
        }
    }
    func testDailySummaryInTodayNote() {
        let todaysDateInNoteTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        
        step("When I go to Today Note"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            noteView = allNotes.openNoteByName(noteTitle: todaysDateInNoteTitleFormat)
        }
        
        verifyDailySummaryInView(view: noteView)
    }
    
    func testDailySummaryInJournal() {
        step("When I open Journal"){
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
        }
        
        verifyDailySummaryInView(view: journalView)
    }
    
    func testNoBulletDragDropAllowedOnDailySummary() {
        
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
