//
//  UpdateViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 21.09.2021.
//

import Foundation
import XCTest

class UpdateViewTests: BaseTest {
    
    func testUpdateViewAppearance() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        testRailPrint("Given I enable Update for the app")
        helper.tapCommand(.setAutoUpdateToMock)
        
        testRailPrint("Then I can open and close it. It has required items")
        let updateView = journalView.clickUpdateNow()
        XCTAssertTrue(updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        updateView.closeUpdateWindow()
        XCTAssertTrue(WaitHelper().waitForDoesntExist( updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier)))
        //Beam app should be a default browser. TBD
        //XCTAssertEqual(journalView.clickUpdateNow().viewAll().getNumberOfTabs(), 1)
    }
    
    func testUpdateAvailableEverywhereInCardView() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        testRailPrint("Given I enable Update for the app")
        helper.tapCommand(.setAutoUpdateToMock)
        XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        journalView.createCardViaOmnibarSearch("Update")
        testRailPrint("Then it is visible in card view")
        XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        let allCardsView = OmniBarTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
        testRailPrint("Then it is visible in All cards view")
        XCTAssertTrue(allCardsView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
