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
    let expectedAutocompleteResultsNumber = 8
    let domainURL = "fr.wikipedia.org"
    let urlToOpen = "fr.wikipedia.org/wiki/Hello_world"
    let partiallyTypedSearchText = "fr.wiki"
    let oneLetterToAdd = "p"
    let anotherOneLetterToAdd = "a"

    override func setUp() {
        launchApp()
    }
    
    func testAutocompleteSelection() {
        testrailId("C1100")
        step("Given I search in Omnibox"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            omniboxView.searchInOmniBox("everest", false)
        }
        
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()
        step("Then I see \(expectedAutocompleteResultsNumber) autocomplete results, no selected results and focused omnibox search"){
            //on different environment goggle offers either 8 or 7 options
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber) || omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber - 1))
            XCTAssertEqual(omniboxView.getSelectedAutocompleteElementQuery().count, 0)
            XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))
        }

        step("When I press down arrow key"){
            omniboxView.typeKeyboardKey(.downArrow)
        }

        let autocompleteSelectedResultQuery = omniboxView.getSelectedAutocompleteElementQuery()
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
            XCTAssertLessThanOrEqual(omniboxView.getNoteAutocompleteElementQuery().count, 1) // default shows 1 today note
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
        testrailId("C1101")
        let expectedFirstResultURLIdentifier = omniboxView.getAutocompleteURLIdentifierFor(domainURL: urlToOpen)
        
        step("Given I open website: \(urlToOpen)"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            omniboxView.searchInOmniBox(urlToOpen, true)
        }

        step("Then browser tab bar appears"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.focusOmniBoxSearchField()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }

        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch
        let autocompleteSelectedResultQuery = omniboxView.getSelectedAutocompleteElementQuery()
        
        step("Then I see \(expectedFirstResultURLIdentifier) identifier and \(urlToOpen) search text available"){
            XCTAssertTrue(waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
            XCTAssertTrue(waitForStringValueEqual(urlToOpen, omniboxView.getOmniBoxSearchField()))
            XCTAssertGreaterThan(results.count, 1)
        }

        step("When I add 1 letter: \(oneLetterToAdd)"){
            omniboxView.getOmniBoxSearchField().typeText(oneLetterToAdd)
        }

        step("Then I see selection persists"){
            XCTAssertTrue(waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
            XCTAssertTrue(waitForStringValueEqual(urlToOpen, omniboxView.getOmniBoxSearchField()))
        }

        step("When I add 1 more letter: \(anotherOneLetterToAdd) which makes the word to be inexisting one"){
            omniboxView.getOmniBoxSearchField().typeText(anotherOneLetterToAdd)
        }
        
        step("Then I see selection is cleared"){
            XCTAssertTrue(waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd + anotherOneLetterToAdd, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }
        
        step("When I press delete"){
            omniboxView.typeKeyboardKey(.delete)
        }
        
        step("Then I see selection is cancelled"){
            XCTAssertTrue(waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I type a letter to make search text reasonable"){
            omniboxView.getOmniBoxSearchField().typeText("e")
        }
        
        step("Then I see selection available"){
            XCTAssertTrue(waitForStringValueEqual(urlToOpen, omniboxView.getOmniBoxSearchField()))
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
        
        step("Then I see search text: \(domainURL + "s")"){
            XCTAssertTrue(waitForStringValueEqual(urlToOpen + "s", omniboxView.getOmniBoxSearchField()))
        }
    }

    func testAutoCompleteHistorySelection() {
        testrailId("C1102")
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let deletePressRepeatTimes = 2
    
        step("GIVEN I populate browser history with mocked data") {
            uiMenu
                .omniboxEnableSearchInHistoryContent()
                .omniboxFillHistory()
        }

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().clickOnExistence()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }
        
        let firstResult = omniboxView.getAutocompleteResults().firstMatch
        let autocompleteSelectedResultQuery = omniboxView.getSelectedAutocompleteElementQuery()

        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
            XCTAssertTrue(waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I type: l"){
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
            XCTAssertTrue(waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I type: a"){
            omniboxView.getOmniBoxSearchField().typeText("a")
        }
        
        step("Then search field value is updated accordingly and non of the results is selected"){
            XCTAssertTrue(waitForStringValueEqual("Hella", omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I press delete \(deletePressRepeatTimes) times and type l"){
            omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is \(expectedSearchFieldText) and 1 result is selected"){
            XCTAssertTrue(waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        }
        
        step("When I press delete \(deletePressRepeatTimes) times"){
            omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        }
        
        step("Then search field value is updated accordingly and non of the results is selected"){
            XCTAssertTrue(waitForStringValueEqual("Hel", omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }

        step("When I type: l"){
            omniboxView.getOmniBoxSearchField().typeText("l")
        }
        
        step("Then search field value is updated accordingly and there is 1 selected result"){
            XCTAssertTrue(waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
            uiMenu.omniboxDisableSearchInHistoryContent()
        }
    }

    func testAutoCompleteHistoryFromAliasUrlSelection() {
        testrailId("C1103")
        let partiallyTypedSearchText = "alter"
        let expectedSearchFieldText = "alternateurl.com"
        let expectedURLIdentifier = omniboxView.getAutocompleteURLIdentifierFor(domainURL: expectedSearchFieldText)
        
        step("GIVEN I populate browser history with mocked data") {
            uiMenu.omniboxFillHistory()
        }

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().clickOnExistence()
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }

        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitForIdentifierEqual(expectedURLIdentifier, omniboxView.getAutocompleteResults().firstMatch))
        }
    }

    func testAutocompleteLeftRightArrowBehavior() {
        testrailId("C1104")
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let expectedURL = "fr.wikipedia.org/wiki/Hello_world"
    
        step("GIVEN I populate browser history with mocked data") {
            uiMenu
                .omniboxDisableSearchInHistoryContent()
                .omniboxFillHistory()
        }

        step("When I type: \(partiallyTypedSearchText)"){
            omniboxView.getOmniBoxSearchField().clickAndType(partiallyTypedSearchText)
        }

        step("Then search field value is \(expectedSearchFieldText)"){
            XCTAssertTrue(waitForIdentifierEqual(expectedHistoryIdentifier, omniboxView.getAutocompleteResults().firstMatch))
            XCTAssertTrue(waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I press right arrow key"){
            omniboxView.typeKeyboardKey(.rightArrow)
        }

        let autocompleteSelectedResultQuery = omniboxView.getSelectedAutocompleteElementQuery()
        
        step("Then I see selection is cleared"){
            XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        }
        
        step("Then search field value is \(expectedURL)"){
            XCTAssertTrue(waitForStringValueEqual(expectedURL, omniboxView.getOmniBoxSearchField()))
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
            XCTAssertTrue(waitForStringValueEqual(partiallyTypedSearchText, omniboxView.getOmniBoxSearchField()))
            uiMenu.omniboxDisableSearchInHistoryContent()
        }
    }
    
    func testAutoCompleteUrlOmniboxDisappear() { //BE-3733
        testrailId("C1105")
        let expectedFirstResultURLIdentifier = omniboxView.getAutocompleteURLIdentifierFor(domainURL: urlToOpen)
        
        step("Given I open website: \(urlToOpen)"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            omniboxView.searchInOmniBox(urlToOpen, true)
        }

        step("Then browser tab bar appears"){
            XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I type: \(partiallyTypedSearchText)"){
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            _ = omniboxView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        }
        
        step("Then I see \(expectedFirstResultURLIdentifier) identifier and \(urlToOpen) search text available"){
            XCTAssertTrue(waitForIdentifierEqual(expectedFirstResultURLIdentifier, omniboxView.getAutocompleteResults().firstMatch))
            XCTAssertTrue(waitForStringValueEqual(urlToOpen, omniboxView.getOmniBoxSearchField()))
        }
        
        step("When I validate autocomplete with Enter"){
            webView.typeKeyboardKey(.enter)
        }
        
        step("Then omnibox disappear"){
            XCTAssertTrue(waitForDoesntExist(omniboxView.getOmniBoxSearchField()))
        }
    }
}
