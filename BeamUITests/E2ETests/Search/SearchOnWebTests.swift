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
        print("Given I open a test page")
        
        helper.openTestPage(page: .page2)
        print("Then by default search field is unavailable")
        XCTAssertFalse(searchView.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        
        print("When I use CMD+F")
        searchView.triggerSearchField()
        print("Then search field appears. Search result options do not exist")
        XCTAssertTrue(searchView.getSearchField().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)

        print("When I search for letter")
        searchView.typeInSearchField("i")
        print("Then search result options appear")
        XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        
        print("Then can I close search field via x icon")
        searchView.closeSearchField()
        XCTAssertFalse(searchView.getSearchField().waitForExistence(timeout: minimumWaitTimeout))
        
        print("Then I can reopen search field again")
        searchView.triggerSearchField()
        XCTAssertTrue(searchView.getSearchField().waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testSearchResultsCounter() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        
        print("Given I open a test page")
        helper.openTestPage(page: .page2)
        
        print("When I search for available letter in text")
        searchView.triggerSearchField()
        searchView.typeInSearchField("i")
        print("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/66"))
        
        print("When I add char to the search keyword")
        searchView.typeInSearchField("-")
        print("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        print("When I navigate backward")
        searchView.navigateBackward(numberOfTimes: 2)
        print("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("3/5"))
        
        print("When I navigate forward")
        searchView.navigateForward(numberOfTimes: 3)
        print("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("5/5"))
        
        print("When I add char to the search keyword to have no results")
        searchView.typeInSearchField("#")
        print("Then I see not found result")
        XCTAssertTrue(searchView.assertResultsCounterNumber(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier))
        
        print("When I remove last char")
        searchView.typeKeyboardKey(.delete)
        print("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        print("When I clear search field")
        searchView.typeKeyboardKey(.delete, 2)
        print("Then search result elements are not visible")
        XCTAssertFalse(searchView.staticText("1/5").waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
    }
    
    func testSearchFieldPasteAndTypeText() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testScrollDownUpToSearchedWord() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testTriggerSearchFieldFromSelectedText() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testSearchResultsHighlights() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "ready"
        let additionalWord = "Video"
        let secondSearch = firstSearch + " " + additionalWord
        let thirdSearch = additionalWord + " " + firstSearch
        
        print("Given I open a test page")
        helper.openTestPage(page: .media)
        
        print("When I search for \(firstSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(firstSearch)
        print("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: firstSearch).count, 2)
        
        print("When I search for \(secondSearch)")
        searchView.typeKeyboardKey(.space)
        searchView.typeInSearchField(additionalWord)
        print("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: secondSearch).count, 0)
        
        print("When correct the search to \(thirdSearch)")
        searchView.typeKeyboardKey(.delete, 6)
        searchView.typeKeyboardKey(.leftArrow, 6)
        searchView.getSearchField().typeText(additionalWord)
        searchView.typeKeyboardKey(.space)
        
        print("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: thirdSearch).count, 1)
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: firstSearch).count, 0)
    }
    
    func testSearchKeywordCaseSensitivityAndSearchAfterReopen() {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        let firstSearch = "ReAdy"
        let secondSearch = "vIDEo"
        let expectedFirstResult = firstSearch.lowercased()
        let expectedSecondResult = "Video"
        
        print("Given I open a test page")
        helper.openTestPage(page: .media)
        
        print("When I search for \(firstSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(firstSearch)
        print("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: expectedFirstResult).count, 2)
        
        print("Then I see no highlight on the web page after I close the search field")
        searchView.closeSearchField()
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: expectedFirstResult).count, 0)
        
        print("When I reopen and search for \(secondSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(secondSearch)
        print("Then I see correct number of results")
        XCTAssertEqual(searchView.app.staticTexts.matching(identifier: expectedSecondResult).count, 2)
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
