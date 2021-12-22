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
        
        testRailPrint("Given I trigger context menu appearance")
        let contextMenuView = cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.slashContextMenu.accessibilityIdentifier)
        XCTAssertTrue(contextMenuView.menuElement().waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I select \(dayToSelect) \(monthToSelect) \(yearToSelect) date in Date picker")
        contextMenuView.clickItem(item: .datePickerItem)
        datePicker.selectYear(year: yearToSelect)
                .selectMonth(month: monthToSelect)
                .selectDate(date: dayToSelect)
        
        testRailPrint("Then \(dayToSelect) \(monthToSelect) \(yearToSelect) card is successfully created and accessible via BiDi link")
        cardTestView.openBiDiLink(0)
        XCTAssertTrue(cardTestView.getCardStaticTitle() == localDateFormat || cardTestView.getCardStaticTitle() == ciDateFormat,
        "\(cardTestView.getCardStaticTitle()) is incorrect comparing to \(localDateFormat) OR \(ciDateFormat)")
    }
    
    func testNoteDividerCreation() {
        let row1Text = "row 1"
        let row2Text = "row 2"
        launchApp()
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        
        testRailPrint("Given I populate 2 notes accordingly with texts: \(row1Text) & \(row2Text)")
        AllCardsTestView()
            .openFirstCard()
            .typeInCardNoteByIndex(noteIndex: 0, text: row1Text)
            .typeKeyboardKey(.enter)
        cardTestView.typeInCardNoteByIndex(noteIndex: 0, text: row2Text)
            .getCardNoteElementByIndex(0)
            .tapInTheMiddle()
        
        testRailPrint("When I add divider item between 2 rows")
        cardTestView.typeKeyboardKey(.space)
        cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.slashContextMenu.accessibilityIdentifier)
            .clickItem(item: .dividerItem)
        
        testRailPrint("Then divider appears in the card area")
        XCTAssertTrue(cardTestView.splitter(CardViewLocators.Splitters.noteDivider.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertEqual(cardTestView.getNumberOfVisibleNotes(), 3)
        XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), row1Text + " ")
        XCTAssertEqual(cardTestView.getCardNoteValueByIndex(1), emptyString)
        XCTAssertEqual(cardTestView.getCardNoteValueByIndex(2), row2Text)
    }
    
}
