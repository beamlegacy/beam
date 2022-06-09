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
    let todayNoteNameCreationViewFormat = DateHelper().getTodaysDateString(.noteViewCreation)
    let todayNoteNameTitleViewFormat = DateHelper().getTodaysDateString(.noteViewTitle)
    let todayNoteNameCreationViewFormatWithout0InDays = DateHelper().getTodaysDateString(.noteViewCreationNoZeros)
    let noteNameToBeCreated = "One Destination"
    let partialSearchKeyword = "One"
    let expectedNumberOfAutocompletedNotes = 1
    let omniboxView = OmniBoxTestView()
    let destinationNoteTitle = OmniBoxTestView().staticText(ToolbarLocators.Labels.noteTitleLabel.accessibilityIdentifier)
    let destinationNoteSearchField = OmniBoxTestView().searchField(ToolbarLocators.SearchFields.destinationNoteSearchField.accessibilityIdentifier)
    let helper = OmniBoxUITestsHelper(OmniBoxTestView().app)
    
    func createDestinationNote(_ journalView: JournalTestView, _ noteNameToBeCreated: String) {
        journalView.app.terminate()
        journalView.app.launch()
        _ = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated).waitForNoteViewToLoad()
    }
    
    func SKIPtestTodayNoteDisplayedByDefault() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("Given I clean the DB and create a note named: \(noteNameToBeCreated)"){
            helper.cleanupDB(logout: false)
            createDestinationNote(journalView, noteNameToBeCreated)
        }

        step("When I search in omnibox and click on destination note"){
            omniboxView.button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).click()
            omniboxView.searchInOmniBox(helper.randomSearchTerm(), true)
            _ = destinationNoteTitle.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            destinationNoteTitle.click()
        }

        step("Then destination note has a focus, empty search field and a note name"){
            _ = destinationNoteSearchField.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            XCTAssertTrue(omniboxView.inputHasFocus(destinationNoteSearchField))
            XCTAssertEqual(journalView.getElementStringValue(element: destinationNoteSearchField), emptyString)
            XCTAssertTrue(destinationNoteSearchField.placeholderValue == todayNoteNameTitleViewFormat || destinationNoteSearchField.placeholderValue == todayNoteNameCreationViewFormat || destinationNoteSearchField.placeholderValue == todayNoteNameCreationViewFormatWithout0InDays,
                          "Actual note name is \(String(describing: destinationNoteSearchField.placeholderValue))")
        }
        
        let selectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
        step("Then Selected autocomplete note is \(expectedNumberOfAutocompletedNotes)"){
            XCTAssertEqual(selectedResultQuery.count, expectedNumberOfAutocompletedNotes)
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
            destinationNoteSearchField.typeText(partialSearchKeyword)
            destinationNoteSearchField.typeText("\r")
        }

        step("Then I see \(noteNameToBeCreated) in search results"){
            XCTAssertEqual(journalView.getElementStringValue(element: destinationNoteTitle), noteNameToBeCreated)
        }
        
        step("When I click escape button"){
            omniboxView.typeKeyboardKey(.escape)
        }
        
        step("Then destination note search field is closed and note title is still displayed"){
            XCTAssertFalse(omniboxView.inputHasFocus(destinationNoteSearchField))
            XCTAssertTrue(destinationNoteTitle.exists)
        }

        step("When I switch to note view and back to web"){
            let noteView = omniboxView.navigateToNoteViaPivotButton()
            noteView.navigateToWebView()
        }

        step("Then I see \(noteNameToBeCreated) as destination note"){
            XCTAssertEqual(journalView.getElementStringValue(element: destinationNoteTitle), noteNameToBeCreated)
        }
    }
    
    func SKIPtestFocusDestinationNoteUsingShortcut() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("Given I clean the DB and create a note named: \(noteNameToBeCreated)"){
            helper.cleanupDB(logout: false)
            createDestinationNote(journalView, noteNameToBeCreated)
        }

        step("When I search in omnibox change note using shortcut"){
            omniboxView.searchInOmniBox(helper.randomSearchTerm(), true)
            _ = destinationNoteTitle.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            shortcutHelper.shortcutActionInvoke(action: .changeDestinationNote)
        }

        step("Then destination note has a focus, empty search field and a note name"){
            _ = destinationNoteSearchField.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            XCTAssertTrue(omniboxView.inputHasFocus(destinationNoteSearchField))
            XCTAssertEqual(journalView.getElementStringValue(element: destinationNoteSearchField), emptyString)
            XCTAssertTrue(destinationNoteSearchField.placeholderValue == todayNoteNameTitleViewFormat || destinationNoteSearchField.placeholderValue == todayNoteNameCreationViewFormat ||
                destinationNoteSearchField.placeholderValue == todayNoteNameCreationViewFormatWithout0InDays,
                          "Actual note name is \(String(describing: destinationNoteSearchField.placeholderValue))")
        }

        step("Then Selected autocomplete note is \(expectedNumberOfAutocompletedNotes)"){
            let selectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
            XCTAssertEqual(selectedResultQuery.count, expectedNumberOfAutocompletedNotes)
        }

    }
}
