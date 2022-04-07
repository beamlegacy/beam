//
//  SearchOnPdfTests.swift
//  BeamUITests
//
//  Created by Andrii on 07/04/2022.
//

import Foundation
import XCTest

class SearchOnPDFTests: BaseTest {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        UITestsMenuBar().destroyDB()
            .startMockHTTPServer()
    }
    
    func testSearchViewAppearace() {
        //launchApp()
        let searchView = SearchTestView()
        let searchText = "Beam"
        
        step("When I open a PDF file") { //To be replaced with Mock PDF page
            OmniBoxTestView().searchInOmniBox("http://www.lvh.me:8080/static/test.pdf", true)
        }
        
        step("When I use CMD+F") {
            searchView.triggerSearchField()
        }
        
        step("Then search field appears. Search result options do not exist"){
            XCTAssertTrue(searchView.getSearchFieldElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("When I search for \(searchText)") {
            searchView.typeInSearchField(searchText)
        }
        
        step("Then search result options appear"){
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(searchView.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).exists)
        }
        
        step("Then I see correct number of results"){
            XCTAssertTrue(searchView.assertResultsCounterNumber("1/3"))
        }
        
        
    }
    
}
