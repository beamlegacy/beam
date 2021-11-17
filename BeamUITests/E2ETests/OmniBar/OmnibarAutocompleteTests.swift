//
//  OmnibarAutocompleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 10.08.2021.
//

import Foundation
import XCTest

class OmnibarAutocompleteTests: BaseTest {
    
    let omnibarView = OmniBarTestView()
    let helper = OmniBarUITestsHelper(OmniBarTestView().app)
    let expectedAutocompleteResultsNumber = 8
    
    func testAutocompleteSelection() {
        launchApp()
        testRailPrint("Given I search in Omnibar")
        omnibarView.searchInOmniBar("everest", false)
        let results = omnibarView.getAutocompleteResults()
        let omnibarSearchField = omnibarView.getOmniBarSearchField()
        
        testRailPrint("Then I see \(expectedAutocompleteResultsNumber) autocomplete results, no selected results and focused omnibar search")
        //on different environment goggle offers either 8 or 7 options
        XCTAssertTrue(omnibarView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber) || omnibarView.waitForAutocompleteResultsLoad(timeout: implicitWaitTimeout, expectedNumber: expectedAutocompleteResultsNumber - 1))
        XCTAssertEqual(results.matching(self.helper.autocompleteSelectedPredicate).count, 0)
        XCTAssertTrue(omnibarView.inputHasFocus(omnibarSearchField))
        
        testRailPrint("When I press down arrow key")
        omnibarView.typeKeyboardKey(.downArrow)
        
        testRailPrint("Then I see 1 selected result from autocomplete")
        let autocompleteSelectedResultQuery = omnibarView.getAutocompleteResults().matching(helper.autocompleteSelectedPredicate)
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        
        testRailPrint("When I press up arrow key")
        omnibarView.typeKeyboardKey(.upArrow)
        
        testRailPrint("Then I see NO selected results from autocomplete")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        XCTAssertTrue(omnibarView.inputHasFocus(omnibarSearchField))
        
        testRailPrint("When I press ESC key 1st time")
        omnibarView.typeKeyboardKey(.escape)
        
        testRailPrint("Then results are hidden, search field is still focused")
        XCTAssertEqual(results.count, 0)
        XCTAssertTrue(omnibarView.inputHasFocus(omnibarSearchField))
        
        testRailPrint("When I press ESC key 2nd time")
        omnibarView.typeKeyboardKey(.escape)
        
        testRailPrint("Then search text is deleted, search field is still focused")
        XCTAssertEqual(omnibarSearchField.value as? String, "")
        XCTAssertTrue(omnibarView.inputHasFocus(omnibarSearchField))
        
        testRailPrint("When I press ESC key 3rd time")
        omnibarView.typeKeyboardKey(.escape)
        
        testRailPrint("Then search field is not focused")
        XCTAssertFalse(omnibarView.inputHasFocus(omnibarSearchField))
    }
    
    func testAutoCompleteURLSelection() {
        launchApp()
        let searchText = "fr.wikipedia.org/wiki/Hello_world"
        let expectedIdentifier = "autocompleteResult-selected-" + searchText
        let expectedFirstResultURLIdentifier = expectedIdentifier + "-url"
        let partiallyTypedSearchText = "fr.wiki"
        let oneLetterToAdd = "p"
        let anotherOneLetterToAdd = "a"
        let helper = OmniBarUITestsHelper(omnibarView.app)
        let waitHelper = WaitHelper()
        
        testRailPrint("Given I open website: \(searchText)")
        let webView = omnibarView.searchInOmniBar(searchText, true)
        
        testRailPrint("Then browser tab bar appears")
        XCTAssertTrue(webView.group(WebViewLocators.Images.browserTabBar.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omnibarView.getOmniBarSearchField().click()
        omnibarView.getOmniBarSearchField().typeText(partiallyTypedSearchText)
        let results = omnibarView.getAutocompleteResults()
        let firstResult = results.firstMatch
        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)
        testRailPrint("Then I see \(expectedFirstResultURLIdentifier) identifier and \(searchText) search text available")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omnibarView.getOmniBarSearchField()))
        XCTAssertTrue(results.count > 1)

        testRailPrint("When I add 1 letter: \(oneLetterToAdd)")
        omnibarView.getOmniBarSearchField().typeText(oneLetterToAdd)
        testRailPrint("Then I see selection persists")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedFirstResultURLIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omnibarView.getOmniBarSearchField()))

        testRailPrint("When I add 1 more letter: \(anotherOneLetterToAdd) which makes the word to be inexisting one")
        omnibarView.getOmniBarSearchField().typeText(anotherOneLetterToAdd)
        testRailPrint("Then I see selection is cleared")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd + anotherOneLetterToAdd, omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I press delete")
        omnibarView.typeKeyboardKey(.delete)
        testRailPrint("Then I see selection is cancelled")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(partiallyTypedSearchText + oneLetterToAdd, omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I type a letter to make search text reasonable")
        omnibarView.getOmniBarSearchField().typeText("e")
        testRailPrint("Then I see selection available")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText, omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        
        testRailPrint("When I move to end of search text via right arrow")
        omnibarView.typeKeyboardKey(.rightArrow)
        testRailPrint("Then I see selection is unavailable")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I type a letter to make search text reasonable")
        omnibarView.getOmniBarSearchField().typeText("s")
        testRailPrint("Then I see search text: \(searchText + "s")")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(searchText + "s", omnibarView.getOmniBarSearchField()))
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
//        helper.tapCommand(.omnibarFillHistory)
//        helper.focusSearchField()
//        omnibarView.getOmniBarSearchField().clear()
//
//        testRailPrint("When I type \(typedTitle)")
//        helper.typeInSearchAndWait("hubert b")
//        let selectedResultQuery = self.helper.allAutocompleteResults.matching(self.helper.autocompleteSelectedPredicate)
//        XCTAssertTrue(selectedResultQuery.firstMatch.waitForExistence(timeout: 10))
////        omnibarView.getOmniBarSearchField().typeSlowly(typedTitle, everyNChar: 5)
//
////         Disable here since we are now displaying google results and there's one maybe later it will change and we will enable that again
//
////        testRailPrint("Then selection is available and search field value is \(expectedFastTypedSearchFieldValue)")
////        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedFastTypedSearchFieldValue, omnibarView.getOmniBarSearchField()), "Actual omnibox value: \(String(describing: omnibarView.getOmniBarSearchField().value))")
////        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
//    }
    
    func testAutoCompleteHistorySelection() {
        let partiallyTypedSearchText = "Hel"
        let expectedSearchFieldText = "Hello world"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let deletePressRepeatTimes = 2
        let waitHelper = WaitHelper()
        
        launchApp()
        helper.tapCommand(.omnibarFillHistory)

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omnibarView.getOmniBarSearchField().click()
        omnibarView.getOmniBarSearchField().typeText(partiallyTypedSearchText)
        let results = omnibarView.getAutocompleteResults()
        let firstResult = results.firstMatch
        
        let autocompleteSelectedResultQuery = helper.allAutocompleteResults.matching(helper.autocompleteSelectedPredicate)

        testRailPrint("Then Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omnibarView.getOmniBarSearchField()))
        
        testRailPrint("When I type: l")
        omnibarView.getOmniBarSearchField().typeText("l")
        testRailPrint("Then Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omnibarView.getOmniBarSearchField()))
        
        testRailPrint("When I type: a")
        omnibarView.getOmniBarSearchField().typeText("a")
        testRailPrint("Then search field value is updated accordingly and non of the results is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual("Hella", omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I press delete \(deletePressRepeatTimes) times and type l")
        omnibarView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        omnibarView.getOmniBarSearchField().typeText("l")
        testRailPrint("Then Then search field value is \(expectedSearchFieldText) and 1 result is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        
        testRailPrint("When I press delete \(deletePressRepeatTimes) times")
        omnibarView.typeKeyboardKey(.delete, deletePressRepeatTimes)
        testRailPrint("Then search field value is updated accordingly and non of the results is selected")
        XCTAssertTrue(waitHelper.waitForStringValueEqual("Hel", omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I type: l")
        omnibarView.getOmniBarSearchField().typeText("l")
        testRailPrint("Then search field value is updated accordingly and there is 1 selected result")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText, omnibarView.getOmniBarSearchField()))
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 1)
        
        testRailPrint("When I press right arrow")
        omnibarView.typeKeyboardKey(.rightArrow)
        testRailPrint("Then non of the results is selected")
        XCTAssertEqual(autocompleteSelectedResultQuery.count, 0)
        
        testRailPrint("When I type: s")
        omnibarView.getOmniBarSearchField().typeText("s")
        testRailPrint("Then search field value is updated accordingly")
        XCTAssertTrue(waitHelper.waitForStringValueEqual(expectedSearchFieldText + "s", omnibarView.getOmniBarSearchField()))
    }

    func testAutoCompleteHistoryFromAliasUrlSelection() {
        let partiallyTypedSearchText = "alternateurl.co"
        let expectedSearchFieldText = "Beam"
        let expectedHistoryIdentifier = "autocompleteResult-selected-\(expectedSearchFieldText)-history"
        let waitHelper = WaitHelper()

        launchApp()
        helper.tapCommand(.omnibarFillHistory)

        testRailPrint("When I type: \(partiallyTypedSearchText)")
        omnibarView.getOmniBarSearchField().click()
        omnibarView.getOmniBarSearchField().typeText(partiallyTypedSearchText)
        let results = omnibarView.getAutocompleteResults()
        let firstResult = results.firstMatch

        testRailPrint("Then search field value is \(expectedSearchFieldText)")
        XCTAssertTrue(waitHelper.waitForIdentifierEqual(expectedHistoryIdentifier, firstResult))
    }
}
