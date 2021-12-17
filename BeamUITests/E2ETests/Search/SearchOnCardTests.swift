//
//  SearchOnCardTests.swift
//  BeamUITests
//
//  Created by Andrii on 04/10/2021.
//

import Foundation
import XCTest

class SearchOnCardTests: BaseTest {
    
    func testSearchViewAppearace() {
        let searchView = prepareTest(populateCardTimes: 2)
        
        testRailPrint("Then by default search field is unavailable")
        XCTAssertFalse(searchView.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("When I use CMD+F")
        searchView.triggerSearchField()
        testRailPrint("Then search field appears. Search result options do not exist")
        XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)

        testRailPrint("When I search for letter")
        searchView.typeInSearchField("t")
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
        let searchView = prepareTest(populateCardTimes: 5)
        
        testRailPrint("When I search for available letter in text")
        searchView.triggerSearchField()
        searchView.typeInSearchField("t")
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/40"))
        
        testRailPrint("When I add char to the search keyword")
        searchView.typeInSearchField(" ")
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/20"))
        
        testRailPrint("When I navigate backward")
        searchView.navigateBackward(numberOfTimes: 2)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("3/20"))
        
        testRailPrint("When I navigate forward")
        searchView.navigateForward(numberOfTimes: 3)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("20/20"))
        
        testRailPrint("When I add char to the search keyword to have no results")
        searchView.typeInSearchField("#")
        testRailPrint("Then I see not found result")
        XCTAssertTrue(searchView.assertResultsCounterNumber(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier))
        
        testRailPrint("When I remove last char")
        searchView.typeKeyboardKey(.delete)
        testRailPrint("Then the results counter is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/20"))
        
        testRailPrint("When I clear search field")
        searchView.typeKeyboardKey(.delete, 2)
        testRailPrint("Then search result elements are not visible")
        XCTAssertFalse(searchView.staticText("1/20").waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
    }
    
    func testSearchKeywordCaseSensitivity() {
        //Impossible to locate highlighted elements, highlight is covered only for web
        let searchView = prepareTest(populateCardTimes: 2)
        let firstSearch = "TeST"

        testRailPrint("When I search for \(firstSearch)")
        searchView.triggerSearchField()
        searchView.typeInSearchField(firstSearch)
        testRailPrint("Then I see correct number of results")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/8"))
    }
    
    func testSearchFieldPasteAndTypeText() {
        let searchView = prepareTest(populateCardTimes: 1)
        let textToPaste = "test 0: "
        
        testRailPrint("When I paste \(textToPaste) in the search field")
        searchView.activateSearchField(isWebSearch: false).pasteText(textToPaste: textToPaste)
        testRailPrint("Then I see correct number of results and pasted text is correct")
        XCTAssertEqual(searchView.getSearchFieldValue(isWebSearch: false), textToPaste)
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/1"))
    }
    
    func testSearchFieldUpdateInstantly() {
        let searchView = prepareTest(populateCardTimes: 1)
        let cardView = CardTestView()
        let textToType = "test"
        
        searchView.activateSearchField(isWebSearch: false).typeInSearchField(textToType, true)
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType, needsActivation: true)
        
        testRailPrint("Then I see number of results is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        testRailPrint("When I delete the last char")
        cardView.typeKeyboardKey(.delete)
        testRailPrint("Then I see number of results is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/4"))
        
        testRailPrint("When I add one more char")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: "t")
        testRailPrint("Then I see number of results is updated correctly")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        testRailPrint("When I add one more char")
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: "t")
        testRailPrint("Then I see number of results is not changed")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        
        testRailPrint("When I delete the last char")
        cardView.typeKeyboardKey(.delete)
        testRailPrint("Then I see number of results is not changed")
        XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
    }
    
    func testSearchFieldLinksReferenceTakenIntoConsideration() throws {
        try XCTSkipIf(true, "WIP once https://linear.app/beamapp/issue/BE-2085/card-search-includes-links-and-references is implemented")
    }
    
    func prepareTest(populateCardTimes: Int) -> SearchTestView {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        JournalTestView().createCardViaOmniboxSearch("Search card")
        testRailPrint("Given I populate the card")
        for _ in 1...populateCardTimes {
            helper.tapCommand(.insertTextInCurrentNote)
        }
        return searchView
    }
}
