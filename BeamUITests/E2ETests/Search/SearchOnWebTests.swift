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
        step("Given I open a test page"){
            helper.openTestPage(page: .page2)
        }
        
        step("Then by default search field is unavailable"){
            XCTAssertFalse(searchView.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        }
        
        step("When I use CMD+F"){
            searchView.triggerSearchField()
        }
        
        step("Then search field appears. Search result options do not exist"){
            XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: implicitWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("When I search for letter"){
            searchView.typeInSearchField("i")
        }
        
        step("Then search result options appear"){
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("Then can I close search field via x icon"){
            searchView.closeSearchField()
            XCTAssertFalse(searchView.getSearchFieldElement().waitForExistence(timeout: minimumWaitTimeout))
        }
        
        step("Then I can reopen search field again"){
            searchView.triggerSearchField()
            XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: implicitWaitTimeout))
        }
        
    }
    
    func testSearchResultsCounter() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        
        step("Given I open a test page"){
            helper.openTestPage(page: .page2)
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
            XCTAssertFalse(searchView.staticText("1/5").waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
    }
    
    func SKIPtestSearchFieldPasteAndTypeText() throws {
        try XCTSkipIf(true, "WIP. Test is blocked by https://linear.app/beamapp/issue/BE-1849/no-search-results-displayed-for-the-string-longer-than-visible-part-of")
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        
        step("Given I open a test page"){
            helper.openTestPage(page: .page2)
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
            searchView.shortcutsHelper
                .shortcutActionInvoke(action: .selectAll)
                .typeKeyboardKey(.delete)
        }
        
    }
    
    func SKIPtestScrollDownUpToSearchedWord() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func SKIPtestTriggerSearchFieldFromSelectedText() throws {
        try XCTSkipIf(true, "WIP once https://linear.app/beamapp/issue/BE-1848/cmd-f-on-selected-text-launches-search-with-pre-filled-query")
    }
    
    func testSearchResultsHighlights() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "test"
        let additionalWord = "Confirm"
        let secondSearch = firstSearch + " " + additionalWord
        let thirdSearch = additionalWord + " " + firstSearch
        
        step("Given I open a test page"){
            helper.openTestPage(page: .alerts)
        }
        
        step("When I search for \(firstSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(firstSearch)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: firstSearch)))
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
            XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: searchView.app.staticTexts.matching(identifier: thirdSearch)))
            XCTAssertEqual(searchView.app.staticTexts.matching(identifier: firstSearch).count, 0)
        }
       
    }
    
    func testSearchKeywordCaseSensitivityAndSearchAfterReopen() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "buTTOn"
        let secondSearch = "cLIcK"
        let expectedFirstResult = firstSearch.lowercased()
        let expectedSecondResult = "Click"
        
        step("Given I open a test page"){
            helper.openTestPage(page: .alerts)
        }
        
        step("When I search for \(firstSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(firstSearch)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: expectedFirstResult)))
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
            XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: searchView.app.staticTexts.matching(identifier: expectedSecondResult)))
        }
        
    }
}
