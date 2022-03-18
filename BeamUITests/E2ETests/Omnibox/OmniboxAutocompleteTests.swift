//
//  OmniboxAutocompleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 10.08.2021.
//

import Foundation
import XCTest

class OmniboxAutocompleteTests: BaseTest {

    let omniboxView = OmniBoxTestView()
    let helper = OmniBoxUITestsHelper(OmniBoxTestView().app)
    let expectedAutocompleteResultsNumber = 8

    func testAutocompleteSelection() {
        launchApp()
        step("Given I search in Omnibox"){
            omniboxView.searchInOmniBox("everest", false)
        }
        
        let results = omniboxView.getAutocompleteResults()
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()

        step("Then I see \(expectedAutocompleteResultsNumber) autocomplete results, no selected results and focused omnibox search"){
            //on different environment goggle offers either 8 or 7 options
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber) || omniboxView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber - 1))
            XCTAssertEqual(results.matching(self.helper.autocompleteSelectedPredicate).count, 0)
            XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        }

        step("When I press down arrow key"){
            omniboxView.typeKeyboardKey(.downArrow)
        }

        let autocompleteSelectedResultQuery = omniboxView.getAutocompleteResults().matching(helper.autocompleteSelectedPredicate)
        step("Then I see 1 selected result from autocomplete"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        }
        
        step("When I press up arrow key"){
            omniboxView.typeKeyboardKey(.upArrow)
        }

        step("Then I see NO selected results from autocomplete"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
            XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        }
        
        step("When I press ESC key 1st time"){
            omniboxView.typeKeyboardKey(.escape)
        }

        step("Then results back to default, search field is empty focused"){
            let noteResults = results.matching(helper.autocompleteNotePredicate)
            XCTAssertLessThanOrEqual(noteResults.count, 1) // default shows 1 today note
            XCTAssertEqual(omniboxView.getSearchFieldValue(), emptyString)
            XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        }
        
        step("When I press ESC key 2nd time"){
            omniboxView.typeKeyboardKey(.escape)
        }
        step("Then the journal omnibox is still here"){
            XCTAssertTrue(omniboxView.getOmniBoxSearchField().exists)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, 0)
        }
    }

    func testAutoCompleteURLSelection() {
        launchApp()
        let searchText = "fr.wikipedia.org/wiki/Hello_world"
        let expectedIdentifier = "autocompleteResult-selected-" + searchText
        let expectedFirstResultURLIdentifier = expectedIdentifier + "-url"
        let partiallyTypedSearchText = "fr.wiki"
        let oneLetterToAdd = "p"
        let anotherOneLetterToAdd = "a"
        let helper = OmniBoxUITestsHelper(omniboxView.app)
        let waitHelper = WaitHelper()
        var webView: WebTestView?

        step("Given I open website: \(searchText)"){
            webView = omniboxView.searchInOmniBox(searchText, true)
        }

        step("Then browser tab bar appears"){
            XCTAssertTrue(webView!.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))
        }

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.focusOmniBoxSearchField()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }

        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch
        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
        
        step("Then I see \(expectedFirstResultURLIdentifier) identifier and \(searchText) search text available"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
            XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))
            XCTAssertTrue(results.count > 1)
        }


        step("When I add 1 letter: \(oneLetterToAdd)"){
            omniboxView.getOmniBoxSearchField().typeText(oneLetterToAdd)
        }

        step("Then I see selection persists"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
            XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))
        }


        step("When I add 1 more letter: \(anotherOneLetterToAdd) which makes the word to be inexisting one"){
            omniboxView.getOmniBoxSearchField().typeText(anotherOneLetterToAdd)
        }
        
        step("Then I see selection is cleared"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd + anotherOneLetterToAdd, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }
        
        step("When I press delete"){
            omniboxView.typeKeyboardKey(.delete)
        }
        
        step("Then I see selection is cancelled"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }


        step("When I type a letter to make search text reasonable"){
            omniboxView.getOmniBoxSearchField().typeText("e")
        }
        
        step("Then I see selection available"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        }

        step("When I move to end of search text via right arrow"){
            omniboxView.typeKeyboardKey(.rightArrow)

        }
        
        step("Then I see selection is unavailable"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I type a letter to make search text reasonable"){
            omniboxView.getOmniBoxSearchField().typeText("s")
        }
        
        step("Then I see search text: \(searchText + "s")"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText + "s", omniboxView.getOmniBoxSearchField()))
        }
    }

    func testAutoCompleteHistorySelection() {
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let deletePressRepeatTimes = 2
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxEnableSearchInHistoryContent)
        helper.tapCommand(.omniboxFillHistory)

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().click()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }
        
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch
        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)

        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I type: l"){
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I type: a"){
            omniboxView.getOmniBoxSearchField().typeText("a")
        }
        
        step("Then search field value is updated accordingly and non of the results is selected"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual("Hella", omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I press delete \(deletePressRepeatTimes) times and type l"){
            omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is \(expectedSearchFieldText) and 1 result is selected"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        }
        
        step("When I press delete \(deletePressRepeatTimes) times"){
            omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        }
        
        step("Then search field value is updated accordingly and non of the results is selected"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual("Hel", omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I type: l"){
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is updated accordingly and there is 1 selected result"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
            helper.tapCommand(.omniboxDisableSearchInHistoryContent)
        }
    }

    func testAutoCompleteHistoryFromAliasUrlSelection() {
        let partiallyTypedSearchText = "alter"
        let expectedSearchFieldText = "alternateurl.com"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-url"
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxFillHistory)

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().click()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }
        
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch

        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        }
    }

    func testAutocompleteLeftRightArrowBehavior() {
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let expectedURL = "fr.wikipedia.org/wiki/Hello_world"
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxEnableSearchInHistoryContent)
        helper.tapCommand(.omniboxFillHistory)

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().click()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }
        
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch


        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I press right arrow key"){
            omniboxView.typeKeyboardKey(.rightArrow)
        }

        let autocompleteSelectedResultQuery = omniboxView.getAutocompleteResults().matching(helper.autocompleteSelectedPredicate)
        
        step("Then I see selection is cleared"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }
        
        step("Then search field value is \(expectedURL)"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedURL, omniboxView.getOmniBoxSearchField()))
        }

        step("When I press down arrow key"){
            omniboxView.typeKeyboardKey(.downArrow)
        }

        step("Then I see 1 selected result from autocomplete"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        }

        step("When I press left arrow key"){
            omniboxView.typeKeyboardKey(.leftArrow)
        }

        step("Then I see selection is cleared"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("Then search field value is \(partiallyTypedSearchText)"){
            XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText, omniboxView.getOmniBoxSearchField()))
            helper.tapCommand(.omniboxDisableSearchInHistoryContent)
        }
    }
}
