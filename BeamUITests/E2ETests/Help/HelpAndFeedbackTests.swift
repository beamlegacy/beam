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
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)

        let expectedCannyLink = "beamapp.canny.io"
        
        
        var menuTitle: XCUIElement?
        var webView: WebTestView?
        
        step("Given I open help menu"){
            helpView = journalView.openHelpMenu()
            menuTitle = helpView!.staticText(HelpViewLocators.StaticTexts.menuTitle.accessibilityIdentifier)
        }

        step("Then \(menuTitle!) is opened"){
            XCTAssertTrue(menuTitle!.waitForExistence(timeout: minimumWaitTimeout))
        }
        
        step("When I close it"){
            helpView!.closeHelpView()
        }
        
        step("Then \(menuTitle!) is closed"){
            XCTAssertTrue(WaitHelper().waitForDoesntExist(menuTitle!))
        }
        
        step("When I open Bug report"){
            webView = journalView.openHelpMenu().openBugReport()
        }

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView!.getNumberOfTabs(), 1)
            let firstTabURL = webView!.getTabUrlAtIndex(index: 0)
            XCTAssertTrue(firstTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(firstTabURL)")
        }

        step("When I open Feature request"){
            let omnibox = OmniBoxTestView()
            omnibox.navigateToCardViaPivotButton()
            journalView.openHelpMenu().openFeatureRequest()
        }

        step("Then a tab with \(expectedCannyLink) is opened"){
            XCTAssertEqual(webView!.getNumberOfTabs(), 2)
            let secondTabURL = webView!.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(secondTabURL.hasPrefix(expectedCannyLink), "Actual web url is \(secondTabURL)")
        }

    }
    
    func testHelpShortcutsView() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        helper.tapCommand(.resizeSquare1000)
        
        step("Given I open shortcuts help menu"){
            helpView = journalView.openHelpMenu().openShortcuts()
        }

        step("Then I am on Shortcusts menu"){
            let cmdLabel = helpView!.image(HelpViewLocators.Images.cmdLabel.accessibilityIdentifier)
            XCTAssertTrue(cmdLabel.waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertEqual(helpView!.getNumberOfCMDLabels(), 25)
        }

        step("When I close shortcuts help menu"){
            helpView!.closeShortcuts()
        }
        
        step("Then I broght back to a note view"){
            XCTAssertTrue(journalView.getHelpButton().waitForExistence(timeout: minimumWaitTimeout))
        }
    }
    
}
