//
//  NotesPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.07.2022.
//

import Foundation
import XCTest

class NotesPreferencesTests: BaseTest {
    
    var journalView: JournalTestView!
    let notesPrefView = NotesPreferencesTestView()
    let notesView = NoteTestView()
    var showBulletsCheckbox: XCUIElement!
    
    override func setUp() {
        journalView = launchApp()
    }
    
    func testIndentationShowBullets() {
        testrailId("C599")
        step("GIVEN I prepare a note with lines") {
            journalView.waitForJournalViewToLoad()
            journalView.createNoteViaOmniboxSearch("Test1")
            uiMenu.insertTextInCurrentNote()
            notesView.typeKeyboardKey(.enter)
            notesView.typeKeyboardKey(.upArrow)
        }
        
        step("GIVEN I open Notes preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            notesPrefView.navigateTo(preferenceView: .notes)
            showBulletsCheckbox = notesPrefView.getAlwaysShowBulletsCheckbox()
        }
    
        step("THEN The bullet is visible when Always show bullets checkbox is enabled") {
            XCTAssertTrue(notesPrefView.staticText(NotesPreferencesViewLocators.StaticTexts.indentationLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            if !showBulletsCheckbox.isSettingEnabled() {
                showBulletsCheckbox.tapInTheMiddle()
            }
            shortcutHelper.shortcutActionInvoke(action: .close)
            notesView.waitForNoteViewToLoad()
            XCTAssertEqual(notesView.getNumberOfVisibleBullets(), 5)
        }
        
        step("WHEN I disable Always show bullets checkbox") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            showBulletsCheckbox.clickOnExistence()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("THEN bullets are not visible anymore") {
            notesView.waitForNoteViewToLoad()
            XCTAssertFalse(notesView.isBulletVisible())
        }
        
        step("WHEN I enable Always show bullets checkbox again") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            showBulletsCheckbox.clickOnExistence()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("THEN correct number of bullets is displayed") {
            notesView.typeKeyboardKey(.downArrow, 3)
            notesView.typeKeyboardKey(.delete)
            notesView.waitForNoteViewToLoad()
            XCTAssertEqual(notesView.getNumberOfVisibleBullets(), 3)
        }
    }
    
    func testCursorColourViewAndSelection() {
        testrailId("C1172")
        let expectedDropDownValuesBlackTheme = ["Black", "Gray", "Blue", "Purple", "Red", "Green"]
        let expectedDropDownValuesLightTheme = ["White", "Gray", "Blue", "Purple", "Red", "Green"]
        let randomColorIndex = Int.random(in: 1..<expectedDropDownValuesBlackTheme.count)
        let colorToSelect = expectedDropDownValuesBlackTheme[randomColorIndex]
        
        step("GIVEN I open Notes preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            notesPrefView.navigateTo(preferenceView: .notes)
        }
        
        step("THEN I see the Cursor color with correct options") {
            XCTAssertTrue(notesPrefView.staticText(NotesPreferencesViewLocators.StaticTexts.cursorColor.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            notesPrefView.getCursorColorDropDownElement().hoverAndTapInTheMiddle()
            let actualDropDownValues = notesPrefView.getCursorColorValues()
            XCTAssertTrue(expectedDropDownValuesBlackTheme == actualDropDownValues || expectedDropDownValuesLightTheme == actualDropDownValues)
        }
        
        step("THEN I successfully select the colour option") {
            XCTAssertTrue(notesPrefView
                .selectCursorColorBy(colorName: colorToSelect)
                .isColorSelectedAs(expectedColorName: colorToSelect), "\(notesPrefView.getCursorColorDropDownElement().getStringValue()) is selected instead of \(colorToSelect)")
        }
        
    }
    
}
