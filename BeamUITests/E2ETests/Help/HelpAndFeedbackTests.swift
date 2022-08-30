//
//  HelpAndFeedback.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class HelpAndFeedbackTests: BaseTest {
    
    var helpView: HelpTestView!
    var journalView: JournalTestView!
    var tabIndex = 0
    
    override func setUp() {
        journalView = launchApp()
        uiMenu.resizeSquare1000()
    }
    
    private func assertCorrectTabIsOpened(_ expectedUrl: String) {
        step ("THEN I see \(expectedUrl) URL opened") {
            let tabToAssert = tabIndex
            tabIndex += 1
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), tabIndex)
            let tabURL = webView.getTabUrlAtIndex(index: tabToAssert)
            XCTAssertTrue(tabURL.hasPrefix(expectedUrl), "Actual web url is \(tabURL)")
        }
    }
    
    func testHelpAndFeedbackAppearance() {
        let expectedCannyLink = "beamapp.canny.io"
        let expectedTwitterTabTitle = "twitter.com/getonbeam"
        var menuTitle: XCUIElement?
        
        step("Given I open help menu"){
            helpView = journalView.openHelpMenu()
            menuTitle = helpView.staticText(HelpViewLocators.StaticTexts.menuTitle.accessibilityIdentifier)
        }

        testrailId("C703")
        step("Then \(menuTitle!) is opened"){
            XCTAssertTrue(menuTitle!.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I close it"){
            helpView.closeHelpView()
        }
        
        step("Then \(menuTitle!) is closed"){
            XCTAssertTrue(waitForDoesntExist(menuTitle!))
        }
        
        testrailId("C706")
        step("When I open Bug report"){
            journalView.openHelpMenu().openBugReport()
        }
        assertCorrectTabIsOpened(expectedCannyLink)
        
        testrailId("C705")
        step("When I open Feature request"){
            let omnibox = OmniBoxTestView()
            omnibox.navigateToNoteViaPivotButton()
            journalView.openHelpMenu().openFeatureRequest()
        }
        assertCorrectTabIsOpened(expectedCannyLink)

        testrailId("C707")
        step("When I open Beam twitter account"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            journalView.openHelpMenu().openTwitterAccount()
        }
        assertCorrectTabIsOpened(expectedTwitterTabTitle)
    }
    
    func testHelpShortcutsView() {
        testrailId("C704")
        step("Given I open shortcuts help menu"){
            helpView = journalView.openHelpMenu().openShortcuts()
        }

        step("Then I am on Shortcusts menu"){
            let cmdLabel = helpView.image(HelpViewLocators.Images.cmdLabel.accessibilityIdentifier)
            XCTAssertTrue(cmdLabel.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(helpView.getNumberOfCMDLabels(), 26)
        }

        step("When I close shortcuts help menu"){
            helpView.closeShortcuts()
        }
        
        step("Then I broght back to a note view"){
            XCTAssertTrue(journalView.getHelpButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
}
