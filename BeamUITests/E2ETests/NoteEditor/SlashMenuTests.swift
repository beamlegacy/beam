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
    var noteTestView: NoteTestView!
    let dayToSelect = "11"
    let monthToSelect = "June"
    let yearToSelect = "2025"
    let textToFormat = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
    
    override func setUp(){
        noteTestView = launchAppAndOpenFirstNote()
    }
    
    func testDatePickerNoteCreation() {
        testrailId("C782")
        let localDateFormat = "\(dayToSelect) \(monthToSelect) \(yearToSelect)"
        let ciDateFormat = "\(monthToSelect) \(dayToSelect), \(yearToSelect)"
        
        let contextMenuView = noteTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)

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
            noteTestView.openBiDiLink(0)
            XCTAssertTrue(noteTestView.getNoteStaticTitle() == localDateFormat || noteTestView.getNoteStaticTitle() == ciDateFormat,
            "\(noteTestView.getNoteStaticTitle()) is incorrect comparing to \(localDateFormat) OR \(ciDateFormat)")
        }

    }
    
    func testNoteDividerCreation() {
        testrailId("C790")
        let row1Text = "row 1"
        let row2Text = "row 2"
        
        step("Given I populate 2 notes accordingly with texts: \(row1Text) & \(row2Text)"){
            noteTestView
                .typeInNoteNodeByIndex(noteIndex: 0, text: row1Text)
                .typeKeyboardKey(.enter)
            noteTestView.typeInNoteNodeByIndex(noteIndex: 0, text: row2Text)
                .getNoteNodeElementByIndex(0)
                .tapInTheMiddle()
        }

        step("When I add divider item between 2 rows"){
            noteTestView.typeKeyboardKey(.space)
            noteTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)
                .clickSlashMenuItem(item: .dividerItem)
        }

        step("Then divider appears in the note area"){
            XCTAssertTrue(noteTestView.splitter(NoteViewLocators.Splitters.noteDivider.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(noteTestView.getNumberOfVisibleNotes(), 3)
            XCTAssertEqual(noteTestView.getNoteNodeValueByIndex(0), row1Text + " ")
            XCTAssertEqual(noteTestView.getNoteNodeValueByIndex(1), emptyString)
            XCTAssertEqual(noteTestView.getNoteNodeValueByIndex(2), row2Text)
        }
    }
    
    func testCheckBoxCreationMovementDeletion() {
        testrailId("C781")
        
        step("Then I can successfuly create a checkbox using a shortcut") {
            noteTestView.waitForTodayNoteViewToLoad()
            noteTestView.createCheckboxAtNote(1)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then the checkbox is removed successfully on delete button press") {
            noteTestView.typeKeyboardKey(.delete)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then I can successfully create a checkbox using slash menu") {
            noteTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier).clickSlashMenuItem(item: .todoCheckboxItem)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then checkbox is created on pressing return button") {
            noteTestView.app.typeText("some text")
            noteTestView.typeKeyboardKey(.leftArrow, 4)
            noteTestView.typeKeyboardKey(.return)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(2).exists)
        }
        
        step("Then all checkboxes are moved one row down on pressing return button") {
            noteTestView.typeKeyboardKey(.upArrow)
            noteTestView.typeKeyboardKey(.return)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(3).exists)
        }
        
        step("Then checkbox is created on pressing return button") {
            noteTestView.typeKeyboardKey(.downArrow)
            noteTestView.typeKeyboardKey(.rightArrow, 4)
            noteTestView.typeKeyboardKey(.return)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(4).exists)
        }
        
        step("Then checkbox is removed on pressing return button") {
            noteTestView.typeKeyboardKey(.return)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(4).exists)
        }
        
        step("Then the text remains on its place after the checkbox removal") {
            noteTestView.typeKeyboardKey(.upArrow)
            noteTestView.typeKeyboardKey(.delete)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(1).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(noteTestView.getCheckboxAtTextNote(2).exists)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(3).exists)
            XCTAssertFalse(noteTestView.getCheckboxAtTextNote(4).exists)
        }
    }
    
    func testSlashMenuTextFormatShortcutsApplying() {
        testrailId("C783, C784, C785, C786, C787, C788, C953")
        step("GIVEN I type text in first note") {
            noteTestView.app.typeText(textToFormat)
        }
        
        step("THEN Text content remains same after applying text format") {
            for item in NoteTestView.TextFormat.allCases {
            
            noteTestView.nodeLineFormatChange(item)
            XCTAssertEqual(noteTestView.getNoteNodeValueByIndex(0), textToFormat)
            
            if item == .heading1 || item == .heading2 {
                noteTestView.shortcutHelper.shortcutActionInvoke(action: .undo)
            }
            else {
                noteTestView.shortcutHelper.shortcutActionInvokeRepeatedly(action: .undo, numberOfTimes: 3)
                }
            }
        }
    }
    
    func testSlashMenuNoteCreation() {
        testrailId("C780")
        let noteNameToBeCreated = "NoteCreation"

        step("Given I create note through slash menu"){
            noteTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier).clickSlashMenuItem(item: .noteItem)
            noteTestView.app.typeText(noteNameToBeCreated)
            noteTestView.typeKeyboardKey(.enter)
        }
        
        step("Then note is successfully created and accessible via BiDi link"){
            noteTestView.openBiDiLink(0)
            XCTAssertTrue(noteTestView.getNoteTitle() == noteNameToBeCreated)
        }
        
        step("And note with \(noteNameToBeCreated) name appears in All notes menu list"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            XCTAssertTrue(AllNotesTestView().isNoteNameAvailable(noteNameToBeCreated))
        }
    }
}
