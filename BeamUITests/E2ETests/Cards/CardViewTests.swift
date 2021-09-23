//
//  CardViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class CardViewTests: BaseTest {
    
    
    func testDefaultCardView() throws {
        try XCTSkipIf(true, "Workaround to open a card from journal/all cards menu is pending")
        let defaultNumberOfCardsAtFreshInstallation = 1
        let journalView = launchApp()
        
        testRailPrint("Given I open All Cards view")
        let allCardsView = journalView.openAllCardsMenu()
        testRailPrint("Then number of cards available by default is \(defaultNumberOfCardsAtFreshInstallation)")
        XCTAssertEqual(defaultNumberOfCardsAtFreshInstallation, allCardsView.getNumberOfCards())
        
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.cardViewTitle)
        let todaysDateInCardCreationDateFormat = DateHelper().getTodaysDateString(.cardViewCreation)
        testRailPrint("When I open \(todaysDateInCardTitleFormat) from Journal view view")
        let cardView = allCardsView.openJournal()
                                    .openRecentCardByName(todaysDateInCardTitleFormat)
        
        testRailPrint("Then the title of the card is \(todaysDateInCardTitleFormat) and its creation date is \(todaysDateInCardCreationDateFormat)")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.staticText(todaysDateInCardCreationDateFormat).exists)
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.editorOptions.accessibilityIdentifier).exists)
        XCTAssertTrue(cardView.staticText(todaysDateInCardTitleFormat).exists)
        
        let defaultNotesCount = 1
        testRailPrint("Then number of notes available by default is \(defaultNotesCount) and it is empty")
        let notes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(notes.count, defaultNotesCount)
        XCTAssertEqual(notes.first?.value as! String, "")
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
