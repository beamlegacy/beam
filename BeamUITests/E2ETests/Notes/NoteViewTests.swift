//
//  CardViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class NoteViewTests: BaseTest {
    
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(.noteViewCreation)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(.noteViewTitle)
    let todayCardNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.noteViewCreationNoZeros)
    
    func SKIPtestDefaultCardView() throws {
        try XCTSkipIf(true, "Workaround to open a note from journal/all notes menu is pending")
        let defaultNumberOfCardsAtFreshInstallation = 1
        let journalView = launchApp()
        var cardView: NoteTestView?
        var allCardsView: AllNotesTestView?
        
        step("Given I open All Notes view"){
            allCardsView = journalView.openAllNotesMenu()
        }
        
        step("Then number of notes available by default is \(defaultNumberOfCardsAtFreshInstallation)"){
            XCTAssertEqual(defaultNumberOfCardsAtFreshInstallation, allCardsView!.getNumberOfNotes())
        }
        
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.noteViewTitle)
        let todaysDateInCardCreationDateFormat = DateHelper().getTodaysDateString(.noteViewCreation)
        step("When I open \(todaysDateInCardTitleFormat) from All notes view"){
            cardView = allCardsView!.openJournal()
                                        .openRecentNoteByName(todaysDateInCardTitleFormat)
        }

        step("Then the title of the note is \(todaysDateInCardTitleFormat) and its creation date is \(todaysDateInCardCreationDateFormat)"){
            cardView!.waitForCardViewToLoad()
            let cardTitle = cardView!.getCardTitle()
            XCTAssertTrue(cardTitle == todayCardNameTitleViewFormat || cardTitle == todayCardNameCreationViewFormat || cardTitle == todayCardNameCreationViewFormatWithout0InDays)
            XCTAssertTrue(cardView!.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
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
