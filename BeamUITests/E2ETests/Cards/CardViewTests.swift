//
//  CardViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class CardViewTests: BaseTest {
    
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(.cardViewCreation)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(.cardViewTitle)
    let todayCardNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.cardViewCreationNoZeros)
    
    func SKIPtestDefaultCardView() throws {
        try XCTSkipIf(true, "Workaround to open a note from journal/all notes menu is pending")
        let defaultNumberOfCardsAtFreshInstallation = 1
        let journalView = launchApp()
        var cardView: CardTestView?
        var allCardsView: AllCardsTestView?
        
        step("Given I open All Notes view"){
            allCardsView = journalView.openAllCardsMenu()
        }
        
        step("Then number of notes available by default is \(defaultNumberOfCardsAtFreshInstallation)"){
            XCTAssertEqual(defaultNumberOfCardsAtFreshInstallation, allCardsView!.getNumberOfCards())
        }
        
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.cardViewTitle)
        let todaysDateInCardCreationDateFormat = DateHelper().getTodaysDateString(.cardViewCreation)
        step("When I open \(todaysDateInCardTitleFormat) from All notes view"){
            cardView = allCardsView!.openJournal()
                                        .openRecentCardByName(todaysDateInCardTitleFormat)
        }

        step("Then the title of the note is \(todaysDateInCardTitleFormat) and its creation date is \(todaysDateInCardCreationDateFormat)"){
            cardView!.waitForCardViewToLoad()
            let cardTitle = cardView!.getCardTitle()
            XCTAssertTrue(cardTitle == todayCardNameTitleViewFormat || cardTitle == todayCardNameCreationViewFormat || cardTitle == todayCardNameCreationViewFormatWithout0InDays)
            XCTAssertTrue(cardView!.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
            XCTAssertTrue(cardView!.staticText(todaysDateInCardCreationDateFormat).exists)
            XCTAssertTrue(cardView!.image(CardViewLocators.Buttons.deleteCardButton.accessibilityIdentifier).exists)
            XCTAssertTrue(cardView!.image(CardViewLocators.Buttons.publishCardButton.accessibilityIdentifier).exists)
            XCTAssertTrue(cardView!.staticText(todaysDateInCardTitleFormat).exists)
        }
        
        let defaultNotesCount = 1
        step("Then number of notes available by default is \(defaultNotesCount) and it is empty"){
            let notes = cardView!.getCardNotesForVisiblePart()
            XCTAssertEqual(notes.count, defaultNotesCount)
            XCTAssertEqual(notes.first?.value as! String, emptyString)
        }

    }
}
