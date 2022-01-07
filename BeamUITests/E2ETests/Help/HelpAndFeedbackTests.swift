//
//  HelpAndFeedback.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class HelpAndFeedbackTests: BaseTest {

    func testHelpAndFeedbackAppearance() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)

        let expectedCannyLink = "beamapp.canny.io"
        testRailPrint("Given I open help menu")
        let helpView = journalView.openHelpMenu()
        let menuTitle = helpView.staticText(HelpViewLocators.StaticTexts.menuTitle.accessibilityIdentifier)
        testRailPrint("Then \(menuTitle) is opened")
        XCTAssertTrue(menuTitle.waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("When I close it")
        helpView.closeHelpView()
        testRailPrint("Then \(menuTitle) is closed")
        XCTAssertTrue(WaitHelper().waitForDoesntExist(menuTitle))
        
        testRailPrint("When I open Bug report")
        let webView = journalView.openHelpMenu().openBugReport()
        let omnibox = OmniBoxTestView()
        testRailPrint("Then a tab with \(expectedCannyLink) is opened")
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        let firstTabURL = webView.getTabUrlAtIndex(index: 0)
        XCTAssertTrue(firstTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(firstTabURL)")
        
        testRailPrint("When I open Feature request")
        omnibox.navigateToCardViaPivotButton()
        journalView.openHelpMenu().openFeatureRequest()
        testRailPrint("Then a tab with \(expectedCannyLink) is opened")
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        let secondTabURL = webView.getTabUrlAtIndex(index: 1)
        XCTAssertTrue(secondTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(secondTabURL)")
    }
    
    func testHelpShortcutsView() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)
        
        testRailPrint("Given I open shortcuts help menu")
        let helpView = journalView.openHelpMenu().openShortcuts()
        let cmdLabel = helpView.image(HelpViewLocators.Images.cmdLabel.accessibilityIdentifier)
        testRailPrint("Then I am on Shortcusts menu")
        XCTAssertTrue(cmdLabel.waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertEqual(helpView.getNumberOfCMDLabels(), 24)
        
        testRailPrint("When I close shortcuts help menu")
        helpView.closeShortcuts()
        testRailPrint("Then I broght back to a card view")
        XCTAssertTrue(journalView.getHelpButton().waitForExistence(timeout: minimumWaitTimeout))
    }
    
}
