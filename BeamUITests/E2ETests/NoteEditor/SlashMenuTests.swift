//
//  SlashMenuTests.swift
//  BeamUITests
//
//  Created by Andrii on 07/12/2021.
//

import Foundation
import XCTest

class SlashMenuTests: BaseTest {
    
    let datePicker = DatePickerTestView()
    var cardTestView: NoteTestView!
    let dayToSelect = "11"
    let monthToSelect = "June"
    let yearToSelect = "2025"
    let textToFormat = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
    
    func testDatePickerCardCreation() {
        let localDateFormat = "\(dayToSelect) \(monthToSelect) \(yearToSelect)"
        let ciDateFormat = "\(monthToSelect) \(dayToSelect), \(yearToSelect)"
        cardTestView = launchAppAndOpenFirstNote()
        
        let contextMenuView = cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)

        step("Given I trigger context menu appearance"){
            XCTAssertTrue(contextMenuView.menuElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I select \(dayToSelect) \(monthToSelect) \(yearToSelect) date in Date picker"){
            contextMenuView.clickSlashMenuItem(item: .datePickerItem)
            datePicker.selectYear(year: yearToSelect)
                    .selectMonth(month: monthToSelect)
                    .selectDate(date: dayToSelect)
        }
        
        step("Then \(dayToSelect) \(monthToSelect) \(yearToSelect) note is successfully created and accessible via BiDi link"){
            cardTestView.openBiDiLink(0)
            XCTAssertTrue(cardTestView.getCardStaticTitle() == localDateFormat || cardTestView.getCardStaticTitle() == ciDateFormat,
            "\(cardTestView.getCardStaticTitle()) is incorrect comparing to \(localDateFormat) OR \(ciDateFormat)")
        }

    }
    
    func testNoteDividerCreation() {
        let row1Text = "row 1"
        let row2Text = "row 2"
        cardTestView = launchAppAndOpenFirstNote()
        
        step("Given I populate 2 notes accordingly with texts: \(row1Text) & \(row2Text)"){
            cardTestView
                .typeInCardNoteByIndex(noteIndex: 0, text: row1Text)
                .typeKeyboardKey(.enter)
            cardTestView.typeInCardNoteByIndex(noteIndex: 0, text: row2Text)
                .getCardNoteElementByIndex(0)
                .tapInTheMiddle()
        }

        step("When I add divider item between 2 rows"){
            cardTestView.typeKeyboardKey(.space)
            cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)
                .clickSlashMenuItem(item: .dividerItem)
        }

        step("Then divider appears in the note area"){
            XCTAssertTrue(cardTestView.splitter(CardViewLocators.Splitters.noteDivider.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(cardTestView.getNumberOfVisibleNotes(), 3)
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), row1Text + " ")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(1), emptyString)
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(2), row2Text)
        }
    }
    
    func testCheckBoxCreationMovementDeletion() {
        cardTestView = launchAppAndOpenFirstNote()

        step("Then I can successfuly create a checkbox using a shortcut") {
            cardTestView.createCheckboxAtNote(1)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then the checkbox is removed successfully on delete button press") {
            cardTestView.typeKeyboardKey(.delete)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then I can successfully create a checkbox using slash menu") {
            cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier).clickSlashMenuItem(item: .todoCheckboxItem)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then checkbox is created on pressing return button") {
            cardTestView.app.typeText("some text")
            cardTestView.typeKeyboardKey(.leftArrow, 4)
            cardTestView.typeKeyboardKey(.return)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(2).exists)
        }
        
        step("Then all checkboxes are moved one row down on pressing return button") {
            cardTestView.typeKeyboardKey(.upArrow)
            cardTestView.typeKeyboardKey(.return)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(3).exists)
        }
        
        step("Then checkbox is created on pressing return button") {
            cardTestView.typeKeyboardKey(.downArrow)
            cardTestView.typeKeyboardKey(.rightArrow, 4)
            cardTestView.typeKeyboardKey(.return)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(4).exists)
        }
        
        step("Then checkbox is removed on pressing return button") {
            cardTestView.typeKeyboardKey(.return)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(4).exists)
        }
        
        step("Then the text remains on its place after the checkbox removal") {
            cardTestView.typeKeyboardKey(.upArrow)
            cardTestView.typeKeyboardKey(.delete)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertFalse(cardTestView.getCheckboxAtTextNote(4).exists)
        }
    }
    
    func testSlashMenuTextFormatShortcutsApplying() {
        
        step("GIVEN I type text in first note") {
            cardTestView = launchAppAndOpenFirstNote()
            cardTestView.app.typeText(textToFormat)
        }
        
        step("THEN Text content remains same after applying text format") {
            for item in NoteTestView.TextFormat.allCases {
            
            cardTestView.nodeLineFormatChange(item)
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), textToFormat)
            
            if item == .heading1 || item == .heading2 {
                cardTestView.shortcutsHelper.shortcutActionInvoke(action: .undo)
            }
            else {
                cardTestView.shortcutsHelper.shortcutActionInvokeRepeatedly(action: .undo, numberOfTimes: 3)
                }
            }
        }
    }
}
