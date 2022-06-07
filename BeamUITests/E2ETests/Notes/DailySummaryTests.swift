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
    
    var cardView: NoteTestView!
    var journalView: JournalTestView!
    var helper: BeamUITestsHelper!
    let webView = WebTestView()
    let shortcuts = ShortcutsHelper()
    let allNotes = AllNotesTestView()
    let linkToOpen = "Pitchfork"
    let pitchForkUrl = "pitchfork.com/"
    let noteToOpen = "Triplego"
    let dummyText = "Dummy Text"
    let startedDailySummaryExpected = "Started Triplego, Laylow. Worked on Alpha Wann, Prince Waly and RA Electronic music online, Pitchfork"
    let continueOnDailySummaryExpected = "Continue on Key Glock, Maxo Kream and LeMonde, Twitter"
    
    override func setUp() {
        journalView = launchApp()

        step("Given I populate daily summary"){
            helper = BeamUITestsHelper(journalView.app)
            helper.tapCommand(.createFakeDailySummary)
            restartApp()
        }
    }
    
    private func verifyDailySummaryInView(view: TextEditorContextTestView){
        step("Then daily summary is displayed"){
            XCTAssertTrue(view.doesStartedDailySummaryExist())
            XCTAssertTrue(view.doesContinueOnDailySummaryExist())
        }

        step("And note contains Started daily summary sentence at second node"){
            XCTAssertEqual(view.getCardNoteValueByIndex(1), startedDailySummaryExpected)
        }

        step("And note contains Continue To daily summary sentence at third node"){
            XCTAssertEqual(view.getCardNoteValueByIndex(2), continueOnDailySummaryExpected)
        }
        
        step("When I open BiDi link Pitchfork"){
            view.openBiDiLink(linkToOpen)
        }
        
        step("Then the webview is opened and Pitchfork is searched"){
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), pitchForkUrl)
        }
        
        step("When I switch back to my note"){
            shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
        }
        
        step("And I open BiDi link Prince Waly"){
            cardView = view.openBiDiLink(noteToOpen)
        }
        
        step("Then note Prince Waly is opened"){
            cardView.waitForCardViewToLoad()
            XCTAssertEqual(cardView.getCardTitle(), noteToOpen)
        }
        
        step("And daily summary is not displayed"){
            XCTAssertFalse(cardView.doesStartedDailySummaryExist())
            XCTAssertFalse(cardView.doesContinueOnDailySummaryExist())
        }
    }
    func testDailySummaryInTodayNote() {
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        
        step("When I go to Today Note"){
            shortcuts.shortcutActionInvoke(action: .showAllNotes)
            cardView = allNotes.openNoteByName(noteTitle: todaysDateInCardTitleFormat)
        }
        
        verifyDailySummaryInView(view: cardView)
    }
    
    func testDailySummaryInJournal() {
        step("When I open Journal"){
            shortcuts.shortcutActionInvoke(action: .showJournal)
        }
        
        verifyDailySummaryInView(view: journalView)
    }
    
    func testNoBulletDragDropAllowedOnDailySummary() {
        
        step("When I open Journal"){
            shortcuts.shortcutActionInvoke(action: .showJournal)
        }
        
        step("And I populate today's note with one text node") {
            journalView.typeInCardNoteByIndex(noteIndex: 0, text: dummyText,  needsActivation: true)
        }
        
        step("And I drag the bullet down") {
            journalView.typeKeyboardKey(.downArrow)
            shortcuts.shortcutActionInvoke(action: .moveBulletDown)
        }
        
        step("Then it has not been inserted in Daily Summary") {
            XCTAssertEqual(journalView.getCardNoteValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(1), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(2), continueOnDailySummaryExpected)
        }
    }
    
    func testDailySummaryCannotBeDeleted() {
        
        step("When I open Journal"){
            shortcuts.shortcutActionInvoke(action: .showJournal)
        }
        
        step("And I populate today's note with one text node") {
            journalView.typeInCardNoteByIndex(noteIndex: 0, text: dummyText,  needsActivation: true)
            journalView.typeKeyboardKey(.enter)
            journalView.typeInCardNoteByIndex(noteIndex: 1, text: dummyText,  needsActivation: true)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(1), dummyText)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(2), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(3), continueOnDailySummaryExpected)
        }
        
        step("Then daily summary is still at the bottom") {
            XCTAssertEqual(journalView.getCardNoteValueByIndex(0), dummyText)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(1), dummyText)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(2), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(3), continueOnDailySummaryExpected)
        }
        
        step("When I delete all note content") {
            shortcuts.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            journalView.typeKeyboardKey(.delete)
        }
        
        step("Then daily summary has not been deleted") {
            XCTAssertEqual(journalView.getCardNoteValueByIndex(0), emptyString)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(1), startedDailySummaryExpected)
            XCTAssertEqual(journalView.getCardNoteValueByIndex(2), continueOnDailySummaryExpected)
        }
    }
    
}
