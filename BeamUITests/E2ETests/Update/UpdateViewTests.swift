//
//  UpdateViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 21.09.2021.
//

import Foundation
import XCTest

class UpdateViewTests: BaseTest {

    private var journalView: JournalTestView!
    private var helper: BeamUITestsHelper!

    override func setUp() {
        journalView = launchApp()
        helper = BeamUITestsHelper(journalView.app)
    }
    
    func testUpdateViewAppearance() {
        step ("Given I enable Update for the app"){
            helper.tapCommand(.setAutoUpdateToMock)
        }
        
        step ("Then I can open and close it. It has required items"){
            let updateView = journalView.clickUpdateNow()
            XCTAssertTrue(updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            updateView.closeUpdateWindow()
            XCTAssertTrue(WaitHelper().waitForDoesntExist( updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier)))
        }
    }
    
    func testUpdateAvailableEverywhereInCardView() {
        step ("Given I enable Update for the app"){
            helper.tapCommand(.setAutoUpdateToMock)
            XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
            journalView.createCardViaOmniboxSearch("Update")
        }

        step ("Then it is visible in note view"){
            XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        }

        step ("Then it is visible in All notes view"){
            let allCardsView = OmniBoxTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
            XCTAssertTrue(allCardsView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        }
    }
}
