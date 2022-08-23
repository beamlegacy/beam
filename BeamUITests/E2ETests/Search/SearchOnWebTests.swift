//
//  SearchOnWebTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation
import XCTest

class SearchOnWebTests: BaseTest {
    
    let waitForCountValueTimeout = TimeInterval(2)
    let searchView = SearchTestView()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        clearPasteboard()
    }
    
    func testSearchViewAppearance() {
        
        step("Given I open a test page"){
            uiMenu.loadUITestPage2()
            webView.waitForWebViewToLoad()
        }
        
        step("Then by default search field is unavailable"){
            XCTAssertFalse(searchView.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I use CMD+F"){
            searchView.triggerSearchField()
        }
        
        step("Then search field appears. Search result options do not exist"){
            XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("When I search for letter"){
            searchView.typeInSearchField("i")
        }
        
        step("Then search result options appear"){
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("Then can I close search field via x icon"){
            searchView.closeSearchField()
            XCTAssertFalse(searchView.getSearchFieldElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then I can reopen search field again"){
            searchView.triggerSearchField()
            XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
    }
    
    func testSearchResultsCounter() {
        
        step("Given I open a test page"){
            uiMenu.loadUITestPage2()
            webView.waitForWebViewToLoad()
        }
        
        step("When I search for available letter in text"){
            searchView.triggerSearchField()
            searchView.typeInSearchField("i")
        }

        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/66"))
        }
        
        step("When I add char to the search keyword"){
            searchView.typeInSearchField("-")
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
        
        step("When I navigate backward"){
            searchView.navigateBackward(numberOfTimes: 2)
        }
        
        step("Then the results counter is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("3/5"))
        }
        
        step("When I navigate forward"){
            searchView.navigateForward(numberOfTimes: 3)
        }
        
        step("Then the results counter is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("5/5"))
        }
        
        step("When I add char to the search keyword to have no results"){
            searchView.typeInSearchField("#")
        }
        
        step("Then I see not found result"){
            XCTAssertTrue(searchView.assertResultsCounterNumber(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier))
        }
        
        step("When I remove last char"){
            searchView.typeKeyboardKey(.delete)
        }
        
        step("Then the results counter is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
        
        step("When I clear search field"){
            searchView.typeKeyboardKey(.delete, 2)
        }
        
        step("Then search result elements are not visible"){
            XCTAssertFalse(searchView.staticText("1/5").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
    }
    
    func SKIPtestSearchFieldPasteAndTypeText() throws {
        try XCTSkipIf(true, "WIP. Test is blocked by https://linear.app/beamapp/issue/BE-1849/no-search-results-displayed-for-the-string-longer-than-visible-part-of")
        
        step("Given I open a test page"){
            uiMenu.loadUITestPage2()
            webView.waitForWebViewToLoad()
        }
        
        let textToPaste1 = "Spanish, Italian"
        _ = "An I-beam, also known as H-beam (for universal column, UC), w-beam (for \"wide flange\"), universal beam (UB), rolled steel joist (RSJ)"
        
        step("When I paste \(textToPaste1) in the search field"){
            searchView.activateSearchField(isWebSearch: true).pasteText(textToPaste: textToPaste1)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/1"))
        }
        
        step("When I clean the text field"){
            searchView.shortcutHelper
                .shortcutActionInvoke(action: .selectAll)
                .typeKeyboardKey(.delete)
        }
        
    }
    
    func SKIPtestScrollDownUpToSearchedWord() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testTriggerSearchFieldFromSelectedText() {
        let searchText = "Ultralight Beam, Kanye West"
        let textElementToSelect = webView.staticText(searchText).firstMatch
        
        step("GIVEN I open a test page and select a text: \(searchText)"){
            uiMenu.loadUITestPage1()
            webView.clickStartOfTextAndDragTillEnd(textIdentifier: searchText, elementToPerformAction: textElementToSelect)
        }
        
        step("WHEN I press CMD+E then CMD+F") {
            shortcutHelper.shortcutActionInvoke(action: .instantTextSearch)
            shortcutHelper.shortcutActionInvoke(action: .search)
        }
        
        step("THEN search option appears"){
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("THEN search field value is: \(searchText)") {
            XCTAssertEqual(searchView.getSearchFieldValue(isWebSearch: true), searchText)
        }
    }
    
    func testSearchResultsHighlights() {
        
        let firstSearch = "test"
        let additionalWord = "Confirm"
        let secondSearch = firstSearch + " " + additionalWord
        let thirdSearch = additionalWord + " " + firstSearch
        
        step("Given I open a test page"){
            uiMenu.loadUITestPageAlerts()
            webView.waitForWebViewToLoad()
        }
        
        step("When I search for \(firstSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(firstSearch)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(waitForCountValueEqual(timeout: waitForCountValueTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: firstSearch)))
        }
        
        step("When I search for \(secondSearch)"){
            searchView.typeKeyboardKey(.space)
            searchView.typeInSearchField(additionalWord)
        }
        
        step("Then I see correct number of results"){
            XCTAssertEqual(searchView.app.staticTexts.matching(identifier: secondSearch).count, 0)
        }
        
        step("When correct the search to \(thirdSearch)"){
            searchView.typeKeyboardKey(.delete, additionalWord.count + 1)
            searchView.typeKeyboardKey(.leftArrow, firstSearch.count)
            searchView.getSearchFieldElement().typeText(additionalWord)
            searchView.typeKeyboardKey(.space)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(waitForCountValueEqual(timeout: waitForCountValueTimeout, expectedNumber: 1, elementQuery: searchView.app.staticTexts.matching(identifier: thirdSearch)))
            XCTAssertEqual(searchView.app.staticTexts.matching(identifier: firstSearch).count, 0)
        }
       
    }
    
    func testSearchKeywordCaseSensitivityAndSearchAfterReopen() {
        
        let firstSearch = "buTTOn"
        let secondSearch = "cLIcK"
        let expectedFirstResult = firstSearch.lowercased()
        let expectedSecondResult = "Click"
        
        step("Given I open a test page"){
            uiMenu.loadUITestPageAlerts()
            webView.waitForWebViewToLoad()
        }
        
        step("When I search for \(firstSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(firstSearch)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(waitForCountValueEqual(timeout: waitForCountValueTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: expectedFirstResult)))
        }
        
        step("Then I see no highlight on the web page after I close the search field"){
            searchView.closeSearchField()
            XCTAssertEqual(searchView.app.staticTexts.matching(identifier: expectedFirstResult).count, 0)
        }
        
        step("When I reopen and search for \(secondSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(secondSearch)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(waitForCountValueEqual(timeout: waitForCountValueTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: expectedSecondResult)))
        }
        
    }
}
