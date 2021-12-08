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
    
}
