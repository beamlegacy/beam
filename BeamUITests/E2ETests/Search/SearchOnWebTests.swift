//
//  SearchOnWebTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation
import XCTest

class SearchOnWebTests: BaseTest {
    
    func testSearchViewAppearance() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        testRailPrint("Given I open a test page")
        
        helper.openTestPage(page: .page2)
        testRailPrint("Then by default search field is unavailable")
        XCTAssertFalse(searchView.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("When I use CMD+F")
        searchView.triggerSearchField()
        testRailPrint("Then search field appears. Search result options do not exist")
        XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)

        testRailPrint("When I search for letter")
        searchView.typeInSearchField("i")
        testRailPrint("Then search result options appear")
        XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        
        testRailPrint("Then can I close search field via x icon")
        searchView.closeSearchField()
        XCTAssertFalse(searchView.getSearchFieldElement().waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("Then I can reopen search field again")
        searchView.triggerSearchField()
        XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testSearchResultsCounter() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        
        testRailPrint("Given I open a test page")
        helper.openTestPage(page: .page2)
        
        testRailPrint("When I search for available letter in text")
        searchView.triggerSearchField()
        searchView.typeInSearchField("i")
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/66"))
        
        testRailPrint("When I add char to the search keyword")
        searchView.typeInSearchField("-")
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        testRailPrint("When I navigate backward")
        searchView.navigateBackward(numberOfTimes: 2)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("3/5"))
        
        testRailPrint("When I navigate forward")
        searchView.navigateForward(numberOfTimes: 3)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("5/5"))
        
        testRailPrint("When I add char to the search keyword to have no results")
        searchView.typeInSearchField("#")
        testRailPrint("Then I see not found result")
        XCTAssertTrue(searchView.assertResultsCounterNumber(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier))
        
        testRailPrint("When I remove last char")
        searchView.typeKeyboardKey(.delete)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        testRailPrint("When I clear search field")
        searchView.typeKeyboardKey(.delete, 2)
        testRailPrint("Then search result elements are not visible")
        XCTAssertFalse(searchView.staticText("1/5").waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
    }
    
    func testSearchFieldPasteAndTypeText() throws {
        try XCTSkipIf(true, "WIP. Test is blocked by https://linear.app/beamapp/issue/BE-1849/no-search-results-displayed-for-the-string-longer-than-visible-part-of")
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        
        testRailPrint("Given I open a test page")
        helper.openTestPage(page: .page2)
        let textToPaste1 = "Spanish, Italian"
        _ = "An I-beam, also known as H-beam (for universal column, UC), w-beam (for \"wide flange\"), universal beam (UB), rolled steel joist (RSJ)"
        testRailPrint("When I paste \(textToPaste1) in the search field")
        searchView.activateSearchField(isWebSearch: true).pasteText(textToPaste: textToPaste1)
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/1"))
        
        testRailPrint("When I clean the text field")
        searchView.shortcutsHelper
            .shortcutActionInvoke(action: .selectAll)
            .typeKeyboardKey(.delete)
    }
    
    func testScrollDownUpToSearchedWord() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testTriggerSearchFieldFromSelectedText() throws {
        try XCTSkipIf(true, "WIP once https://linear.app/beamapp/issue/BE-1848/cmd-f-on-selected-text-launches-search-with-pre-filled-query")
    }
    
    func testSearchResultsHighlights() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "ready"
        let additionalWord = "Video"
        let secondSearch = firstSearch + " " + additionalWord
        let thirdSearch = additionalWord + " " + firstSearch
        
        testRailPrint("Given I open a test page")
        helper.openTestPage(page: .media)
        
        testRailPrint("When I search for \(firstSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(firstSearch)
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: searchView.app.staticTexts.matching(identifier: firstSearch)))
        
        testRailPrint("When I search for \(secondSearch)")
        searchView.typeKeyboardKey(.space)
        searchView.typeInSearchField(additionalWord)
        testRailPrint("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: secondSearch).count, 0)
        
        testRailPrint("When correct the search to \(thirdSearch)")
        searchView.typeKeyboardKey(.delete, 6)
        searchView.typeKeyboardKey(.leftArrow, 6)
        searchView.getSearchFieldElement().typeText(additionalWord)
        searchView.typeKeyboardKey(.space)
        
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: searchView.app.staticTexts.matching(identifier: thirdSearch)))
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: firstSearch).count, 0)
    }
    
    func testSearchKeywordCaseSensitivityAndSearchAfterReopen() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "ReAdy"
        let secondSearch = "vIDEo"
        let expectedFirstResult = firstSearch.lowercased()
        let expectedSecondResult = "Video"
        
        testRailPrint("Given I open a test page")
        helper.openTestPage(page: .media)
        
        testRailPrint("When I search for \(firstSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(firstSearch)
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: searchView.app.staticTexts.matching(identifier: expectedFirstResult)))
        
        testRailPrint("Then I see no highlight on the web page after I close the search field")
        searchView.closeSearchField()
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: expectedFirstResult).count, 0)
        
        testRailPrint("When I reopen and search for \(secondSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(secondSearch)
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: searchView.app.staticTexts.matching(identifier: expectedSecondResult)))
    }
}
