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
    let cardTestView = CardTestView()
    let dayToSelect = "11"
    let monthToSelect = "June"
    let yearToSelect = "2025"
    
    func testDatePickerCardCreation() {
        let localDateFormat = "\(dayToSelect) \(monthToSelect) \(yearToSelect)"
        let ciDateFormat = "\(monthToSelect) \(dayToSelect), \(yearToSelect)"
        launchApp()
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        AllCardsTestView().openFirstCard()
        
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
        launchApp()
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        
        step("Given I populate 2 notes accordingly with texts: \(row1Text) & \(row2Text)"){
            AllCardsTestView()
                .openFirstCard()
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
}
