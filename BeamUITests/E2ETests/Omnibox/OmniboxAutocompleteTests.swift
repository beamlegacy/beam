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
        testRailPrint("Given I search in Omnibox")
        omniboxView.searchInOmniBox("everest", false)
        let results = omniboxView.getAutocompleteResults()
        let omniboxSearchField = omniboxView.getOmniBoxSearchField()

        testRailPrint("Then I see \(expectedAutocompleteResultsNumber) autocomplete results, no selected results and focused omnibox search")
        //on different environment goggle offers either 8 or 7 options
        XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber) || omniboxView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber - 1))
        XCTAssertEqual(results.matching(self.helper.autocompleteSelectedPredicate).count, 0)
        XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))

        testRailPrint("When I press down arrow key")
        omniboxView.typeKeyboardKey(.downArrow)

        testRailPrint("Then I see 1 selected result from autocomplete")
        let autocompleteSelectedResultQuery = omniboxView.getAutocompleteResults().matching(helper.autocompleteSelectedPredicate)
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)

        testRailPrint("When I press up arrow key")
        omniboxView.typeKeyboardKey(.upArrow)

        testRailPrint("Then I see NO selected results from autocomplete")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))

        testRailPrint("When I press ESC key 1st time")
        omniboxView.typeKeyboardKey(.escape)

        testRailPrint("Then results back to default, search field is empty focused")
        XCTAssertLessThanOrEqual(results.count, 1) // default shows 1 today note
        XCTAssertEqual(omniboxSearchField.value as? String, "")
        XCTAssertTrue(omniboxView.inputHasFocus(omniboxSearchField))

        testRailPrint("When I press ESC key 2nd time")
        omniboxView.typeKeyboardKey(.escape)
        testRailPrint("Then omnibox is dismissed")
        XCTAssertFalse(omniboxView.getOmniBoxSearchField().exists)
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

        testRailPrint("Given I open website: \(searchText)")
        let webView = omniboxView.searchInOmniBox(searchText, true)

        testRailPrint("Then browser tab bar appears")
        XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omniboxView.focusOmniBoxSearchField()
        omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch
        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
        testRailPrint("Then I see \(expectedFirstResultURLIdentifier) identifier and \(searchText) search text available")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))
        XCTAssertTrue(results.count > 1)

        testRailPrint("When I add 1 letter: \(oneLetterToAdd)")
        omniboxView.getOmniBoxSearchField().typeText(oneLetterToAdd)
        testRailPrint("Then I see selection persists")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))

        testRailPrint("When I add 1 more letter: \(anotherOneLetterToAdd) which makes the word to be inexisting one")
        omniboxView.getOmniBoxSearchField().typeText(anotherOneLetterToAdd)
        testRailPrint("Then I see selection is cleared")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd + anotherOneLetterToAdd, omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("When I press delete")
        omniboxView.typeKeyboardKey(.delete)
        testRailPrint("Then I see selection is cancelled")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd, omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("When I type a letter to make search text reasonable")
        omniboxView.getOmniBoxSearchField().typeText("e")
        testRailPrint("Then I see selection available")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)

        testRailPrint("When I move to end of search text via right arrow")
        omniboxView.typeKeyboardKey(.rightArrow)
        testRailPrint("Then I see selection is unavailable")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("When I type a letter to make search text reasonable")
        omniboxView.getOmniBoxSearchField().typeText("s")
        testRailPrint("Then I see search text: \(searchText + "s")")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText + "s", omniboxView.getOmniBoxSearchField()))
    }

//    func testFastTypeAutocompleteHistory() {
//        let titleWiki = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr."
//        let typedTitle = titleWiki.lowercased().substring(from: 3, to: titleWiki.count - 6)
//        let endTypingAtIndex = titleWiki.count - 6
//        let expectedFastTypedSearchFieldValue = titleWiki.lowercased().substring(from: 0, to: endTypingAtIndex) + titleWiki.substring(from: endTypingAtIndex, to: titleWiki.count)
//
//        let waitHelper = WaitHelper()
//        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
//        launchApp()
//        helper.tapCommand(.omniboxFillHistory)
//        helper.focusSearchField()
//        omniboxView.getOmniBoxSearchField().clear()
//
//        testRailPrint("When I type \(typedTitle)")
//        helper.typeInSearchAndWait("hubert b")
//        let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
//        XCTAssertTrue(selectedResultQuery.firstMatch.waitForExistence(timeout: 10))
////        omniboxView.getOmniBoxSearchField().typeSlowly(typedTitle, everyNChar: 5)
//
////         Disable here since we are now displaying google results and there's one maybe later it will change and we will enable that again
//
////        testRailPrint("Then selection is available and search field value is \(expectedFastTypedSearchFieldValue)")
////        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedFastTypedSearchFieldValue, omniboxView.getOmniBoxSearchField()), "Actual omnibox value: \(String(describing: omniboxView.getOmniBoxSearchField().value))")
////        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
//    }

    func testAutoCompleteHistorySelection() {
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let deletePressRepeatTimes = 2
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxFillHistory)

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omniboxView.getOmniBoxSearchField().click()
        omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch

        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)

        testRailPrint("Then Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))

        testRailPrint("When I type: l")
        omniboxView.getOmniBoxSearchField().typeText("l")
        testRailPrint("Then Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))

        testRailPrint("When I type: a")
        omniboxView.getOmniBoxSearchField().typeText("a")
        testRailPrint("Then search field value is updated accordingly and non of the results is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual("Hella", omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("When I press delete \(deletePressRepeatTimes) times and type l")
        omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        omniboxView.getOmniBoxSearchField().typeText("l")
        testRailPrint("Then Then search field value is \(expectedSearchFieldText) and 1 result is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)

        testRailPrint("When I press delete \(deletePressRepeatTimes) times")
        omniboxView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        testRailPrint("Then search field value is updated accordingly and non of the results is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual("Hel", omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("When I type: l")
        omniboxView.getOmniBoxSearchField().typeText("l")
        testRailPrint("Then search field value is updated accordingly and there is 1 selected result")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
    }

    func testAutoCompleteHistoryFromAliasUrlSelection() {
        let partiallyTypedSearchText = "alter"
        let expectedSearchFieldText = "alternateurl.com"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-url"
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxFillHistory)

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omniboxView.getOmniBoxSearchField().click()
        omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch

        testRailPrint("Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
    }

    func testAutocompleteLeftRightArrowBehavior() {
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let expectedURL = "fr.wikipedia.org/wiki/Hello_world"
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omniboxFillHistory)

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omniboxView.getOmniBoxSearchField().click()
        omniboxView.getOmniBoxSearchField().typeText(partiallyTypedSearchText)
        let results = omniboxView.getAutocompleteResults()
        let firstResult = results.firstMatch


        testRailPrint("Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omniboxView.getOmniBoxSearchField()))

        testRailPrint("When I press right arrow key")
        omniboxView.typeKeyboardKey(.rightArrow)

        testRailPrint("Then I see selection is cleared")
        let autocompleteSelectedResultQuery = omniboxView.getAutocompleteResults().matching(helper.autocompleteSelectedPredicate)
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("Then search field value is \(expectedURL)")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedURL, omniboxView.getOmniBoxSearchField()))

        testRailPrint("When I press down arrow key")
        omniboxView.typeKeyboardKey(.downArrow)

        testRailPrint("Then I see 1 selected result from autocomplete")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)

        testRailPrint("When I press left arrow key")
        omniboxView.typeKeyboardKey(.leftArrow)

        testRailPrint("Then I see selection is cleared")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)

        testRailPrint("Then search field value is \(partiallyTypedSearchText)")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText, omniboxView.getOmniBoxSearchField()))
    }
}
