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
    
    override func setUp() {
        journalView = launchApp()
        uiMenu.resizeSquare1000()
    }
    
    func testHelpAndFeedbackAppearance() {
        let expectedCannyLink = "beamapp.canny.io"
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

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            let firstTabURL = webView.getTabUrlAtIndex(index: 0)
            XCTAssertTrue(firstTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(firstTabURL)")
        }
        
        testrailId("C705")
        step("When I open Feature request"){
            let omnibox = OmniBoxTestView()
            omnibox.navigateToNoteViaPivotButton()
            journalView.openHelpMenu().openFeatureRequest()
        }

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            let secondTabURL = webView.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(secondTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(secondTabURL)")
        }

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
