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
            searchView.typeInSearchField("t")
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
        let searchView = prepareTest(populateCardTimes: 5)
        
        step("When I search for available letter in text"){
            searchView.triggerSearchField()
            searchView.typeInSearchField("t")
        }

        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/40"))
        }
        
        step("When I add char to the search keyword"){
            searchView.typeInSearchField(" ")
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/20"))
        }
        
        step("When I navigate backward"){
            searchView.navigateBackward(numberOfTimes: 2)
        }
        
        step("Then the results counter is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("3/20"))
        }
        
        step("When I navigate forward"){
            searchView.navigateForward(numberOfTimes: 3)
        }
        
        step("Then the results counter is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("20/20"))
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
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/20"))
        }
        
        step("When I clear search field"){
            searchView.typeKeyboardKey(.delete, 2)
        }
        
        step("Then search result elements are not visible"){
            XCTAssertFalse(searchView.staticText("1/20").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.staticText(SearchViewLocators.StaticTexts.emptySearchResult.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
    }
    
    func testSearchKeywordCaseSensitivity() {
        //Impossible to locate highlighted elements, highlight is covered only for web
        let searchView = prepareTest(populateCardTimes: 2)
        let firstSearch = "TeST"

        step("When I search for \(firstSearch)"){
            searchView.triggerSearchField()
            searchView.typeInSearchField(firstSearch)
        }

        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/8"))
        }
    }
    
    func testSearchFieldPasteAndTypeText() {
        let searchView = prepareTest(populateCardTimes: 1)
        let textToPaste = "test 0: "
        
        step("When I paste \(textToPaste) in the search field"){
            searchView.activateSearchField(isWebSearch: false).pasteText(textToPaste: textToPaste)
        }
        
        step("Then I see correct number of results and pasted text is correct"){
            XCTAssertEqual(searchView.getSearchFieldValue(isWebSearch: false), textToPaste)
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/1"))
        }
    }
    
    func testSearchFieldUpdateInstantly() {
        let searchView = prepareTest(populateCardTimes: 1)
        let cardView = CardTestView()
        let textToType = "test"
        
        searchView.activateSearchField(isWebSearch: false).typeInSearchField(textToType, true)
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType, needsActivation: true)
        
        step("Then I see number of results is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
        
        step("When I delete the last char"){
            cardView.typeKeyboardKey(.delete)
        }
        
        step("Then I see number of results is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/4"))
        }
        
        step("When I add one more char"){
            cardView.typeInCardNoteByIndex(noteIndex: 0, text: "t")
        }
        
        step("Then I see number of results is updated correctly"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
        
        step("When I add one more char"){
            cardView.typeInCardNoteByIndex(noteIndex: 0, text: "t")
        }
        
        step("Then I see number of results is not changed"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
        
        step("When I delete the last char"){
            cardView.typeKeyboardKey(.delete)
        }
        
        step("Then I see number of results is not changed"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/5"))
        }
    }
    
    func SKIPtestSearchFieldLinksReferenceTakenIntoConsideration() throws {
        try XCTSkipIf(true, "WIP once https://linear.app/beamapp/issue/BE-2085/card-search-includes-links-and-references is implemented")
    }
    
    func prepareTest(populateCardTimes: Int) -> SearchTestView {
        let helper = BeamUITestsHelper(launchApp().app)
        let searchView = SearchTestView()
        JournalTestView().createCardViaOmniboxSearch("SearchNote") //backspace is not typed sometimes on CI machines, camel case is used instead
        step("Given I populate the note"){
            for _ in 1...populateCardTimes {
                helper.tapCommand(.insertTextInCurrentNote)
            }
        }
        
        return searchView
    }
}
