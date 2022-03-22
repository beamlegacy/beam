//
//  OmniboxDestinationTests.swift
//  BeamUITests
//
//  Created by Andrii on 10.08.2021.
//

import Foundation
import XCTest

class OmniboxDestinationTests: BaseTest {
    
    //Workaround for https://linear.app/beamapp/issue/BE-1900/default-card-name-format-is-flexible-depending-on-users-locationdate
    let todayCardNameCreationViewFormat = DateHelper().getTodaysDateString(.cardViewCreation)
    let todayCardNameTitleViewFormat = DateHelper().getTodaysDateString(.cardViewTitle)
    let todayCardNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.cardViewCreationNoZeros)
    let cardNameToBeCreated = "One Destination"
    let partialSearchKeyword = "One"
    let expectedNumberOfAutocompletedCards = 1
    let omniboxView = OmniBoxTestView()
    let destinationCardTitle = OmniBoxTestView().staticText(ToolbarLocators.Labels.cardTitleLabel.accessibilityIdentifier)
    let destinationCardSearchField = OmniBoxTestView().searchField(ToolbarLocators.SearchFields.destinationCardSearchField.accessibilityIdentifier)
    let helper = OmniBoxUITestsHelper(OmniBoxTestView().app)
    
    func createDestinationNote(_ journalView: JournalTestView, _ cardNameToBeCreated: String) {
        journalView.app.terminate()
        journalView.app.launch()
        _ = journalView.createCardViaOmniboxSearch(cardNameToBeCreated).waitForCardViewToLoad()
    }
    
    func SKIPtestTodayCardDisplayedByDefault() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("Given I clean the DB and create a note named: \(cardNameToBeCreated)"){
            helper.cleanupDB(logout: false)
            createDestinationNote(journalView, cardNameToBeCreated)
        }

        step("When I search in omnibox and click on destination note"){
            omniboxView.button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).click()
            omniboxView.searchInOmniBox(helper.randomSearchTerm(), true)
            _ = destinationCardTitle.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            destinationCardTitle.click()
        }

        step("Then destination note has a focus, empty search field and a note name"){
            _ = destinationCardSearchField.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            XCTAssertTrue(omniboxView.inputHasFocus(destinationCardSearchField))
            XCTAssertEqual(journalView.getElementStringValue(element: destinationCardSearchField), emptyString)
            XCTAssertTrue(destinationCardSearchField.placeholderValue == todayCardNameTitleViewFormat || destinationCardSearchField.placeholderValue == todayCardNameCreationViewFormat || destinationCardSearchField.placeholderValue == todayCardNameCreationViewFormatWithout0InDays,
                          "Actual note name is \(String(describing: destinationCardSearchField.placeholderValue))")
        }
        
        let selectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
        step("Then Selected autocomplete note is \(expectedNumberOfAutocompletedCards)"){
            XCTAssertEqual(selectedResultQuery.count, expectedNumberOfAutocompletedCards)
        }

        let firstResult = selectedResultQuery.firstMatch.identifier
        step("When I click down arrow"){
            omniboxView.typeKeyboardKey(.downArrow)
        }
        let secondResult = selectedResultQuery.firstMatch.identifier
        step("Then destination note is changed"){
            XCTAssertNotEqual(secondResult, firstResult)
        }
        
        step("When I click up arrow"){
            omniboxView.typeKeyboardKey(.upArrow)
        }
        let thirdResult = selectedResultQuery.firstMatch.identifier

        step("Then destination note is changed back"){
            XCTAssertEqual(thirdResult, firstResult)
        }
        
        step("When I type in search field: \(partialSearchKeyword)"){
            destinationCardSearchField.typeText(partialSearchKeyword)
            destinationCardSearchField.typeText("\r")
        }

        step("Then I see \(cardNameToBeCreated) in search results"){
            XCTAssertEqual(journalView.getElementStringValue(element: destinationCardTitle), cardNameToBeCreated)
        }
        
        step("When I click escape button"){
            omniboxView.typeKeyboardKey(.escape)
        }
        
        step("Then destination note search field is closed and note title is still displayed"){
            XCTAssertFalse(omniboxView.inputHasFocus(destinationCardSearchField))
            XCTAssertTrue(destinationCardTitle.exists)
        }

        step("When I switch to note view and back to web"){
            let cardView = omniboxView.navigateToCardViaPivotButton()
            cardView.navigateToWebView()
        }

        step("Then I see \(cardNameToBeCreated) as destination note"){
            XCTAssertEqual(journalView.getElementStringValue(element: destinationCardTitle), cardNameToBeCreated)
        }
    }
    
    func SKIPtestFocusDestinationCardUsingShortcut() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("Given I clean the DB and create a note named: \(cardNameToBeCreated)"){
            helper.cleanupDB(logout: false)
            createDestinationNote(journalView, cardNameToBeCreated)
        }

        step("When I search in omnibox change note using shortcut"){
            omniboxView.searchInOmniBox(helper.randomSearchTerm(), true)
            _ = destinationCardTitle.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            ShortcutsHelper().shortcutActionInvoke(action: .changeDestinationCard)
        }

        step("Then destination note has a focus, empty search field and a note name"){
            _ = destinationCardSearchField.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            XCTAssertTrue(omniboxView.inputHasFocus(destinationCardSearchField))
            XCTAssertEqual(journalView.getElementStringValue(element: destinationCardSearchField), emptyString)
            XCTAssertTrue(destinationCardSearchField.placeholderValue == todayCardNameTitleViewFormat || destinationCardSearchField.placeholderValue == todayCardNameCreationViewFormat ||
                destinationCardSearchField.placeholderValue == todayCardNameCreationViewFormatWithout0InDays,
                          "Actual note name is \(String(describing: destinationCardSearchField.placeholderValue))")
        }

        step("Then Selected autocomplete note is \(expectedNumberOfAutocompletedCards)"){
            let selectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
            XCTAssertEqual(selectedResultQuery.count, expectedNumberOfAutocompletedCards)
        }

    }
}
