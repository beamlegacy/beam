//
//  HelpAndFeedback.swift
//  BeamUITests
//
//  Created by Andrii on 20.09.2021.
//

import Foundation
import XCTest

class HelpAndFeedbackTests: BaseTest {
    var helpView: HelpTestView?
    
    func testHelpAndFeedbackAppearance() {
        let journalView = launchApp()
        uiMenu.resizeSquare1000()

        let expectedCannyLink = "beamapp.canny.io"
        
        
        var menuTitle: XCUIElement?
        var webView: WebTestView?
        
        step("Given I open help menu"){
            helpView = journalView.openHelpMenu()
            menuTitle = helpView!.staticText(HelpViewLocators.StaticTexts.menuTitle.accessibilityIdentifier)
        }

        step("Then \(menuTitle!) is opened"){
            XCTAssertTrue(menuTitle!.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I close it"){
            helpView!.closeHelpView()
        }
        
        step("Then \(menuTitle!) is closed"){
            XCTAssertTrue(waitForDoesntExist(menuTitle!))
        }
        
        step("When I open Bug report"){
            webView = journalView.openHelpMenu().openBugReport()
        }

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView!.getNumberOfTabs(wait: true), 1)
            let firstTabURL = webView!.getTabUrlAtIndex(index: 0)
            XCTAssertTrue(firstTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(firstTabURL)")
        }

        step("When I open Feature request"){
            let omnibox = OmniBoxTestView()
            omnibox.navigateToNoteViaPivotButton()
            journalView.openHelpMenu().openFeatureRequest()
        }

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView!.getNumberOfTabs(wait: true), 2)
            let secondTabURL = webView!.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(secondTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(secondTabURL)")
        }

    }
    
    func testHelpShortcutsView() {
        let journalView = launchApp()
        uiMenu.resizeSquare1000()
        
        step("Given I open shortcuts help menu"){
            helpView = journalView.openHelpMenu().openShortcuts()
        }

        step("Then I am on Shortcusts menu"){
            let cmdLabel = helpView!.image(HelpViewLocators.Images.cmdLabel.accessibilityIdentifier)
            XCTAssertTrue(cmdLabel.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(helpView!.getNumberOfCMDLabels(), 26)
        }

        step("When I close shortcuts help menu"){
            helpView!.closeShortcuts()
        }
        
        step("Then I broght back to a note view"){
            XCTAssertTrue(journalView.getHelpButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
}
