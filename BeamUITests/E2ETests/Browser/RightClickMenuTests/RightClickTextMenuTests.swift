//
//  RightClickTextMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 08/07/2022.
//

import Foundation
import XCTest

class RightClickTextMenuTests: BaseTest {
    let rightClickMenuTestView = RightClickMenuTestView()
    let omniboxTestView = OmniBoxTestView()
    
    let textToRightClickOn = WebTestView().staticText("H-beam")
    let expectedSearchTextPart1 = "beam - "
    let expectedSearchTextPart2 = "Google"
    
    private func verifyMenuForText () {
        //wait for menu to be displayed - inspect element should always be displayed
        rightClickMenuTestView.waitForMenuToBeDisplayed()

        for item in RightClickMenuViewLocators.TextMenuItems.allCases {
            // Translate menu not available on Big Sur
            if !(self.isBigSurOS() && item.accessibilityIdentifier == "WKMenuItemIdentifierTranslate") {
                XCTAssertTrue(app.menuItems[item.accessibilityIdentifier].exists)
            }
        }
        for item in RightClickMenuViewLocators.CommonMenuItems.allCases {
            XCTAssertTrue(app.menuItems[item.accessibilityIdentifier].exists)
        }
    }
    
    override func setUp() {
        step("Given I open test page") {
            launchApp()
            uiMenu.loadUITestPage2()
        }
        
        step("When I right click on a text") {
            textToRightClickOn.rightClick()
        }
        
        step("Then menu is displayed") {
            verifyMenuForText()
        }
    }
    
    func testRightClickTextLookUp() throws {
        testrailId("C844")
        // Look Up option is a system option.
        // I will verify option is filled with the word and we can click on it
        step("Then look up option is filled with keyword") {
            XCTAssertEqual(app.menuItems[RightClickMenuViewLocators.TextMenuItems.lookUpText.accessibilityIdentifier].title, "Look Up “beam”")
        }
        
        step("And I can click on it without crash") {
            rightClickMenuTestView.clickTextMenu(.lookUpText)
        }
    }
    
    func testRightClickTextTranslate() throws {
        testrailId("C845")
        try XCTSkipIf(isBigSurOS(), "Not available on BigSur")
        // Look Up option is a system option.
        // I will verify option is filled with the word and we can click on it
        step("Then look up option is filled with keyword") {
            XCTAssertEqual(app.menuItems[RightClickMenuViewLocators.TextMenuItems.translateText.accessibilityIdentifier].title, "Translate “beam”")
        }
        
        step("And I can click on it without crash") {
            rightClickMenuTestView.clickTextMenu(.translateText)
        }
    }
    
    func testRightClickSearchGoogleText() throws {
        testrailId("C846")
        step("When I search text with Google") {
            rightClickMenuTestView.clickTextMenu(.searchWithGoogle)
        }
        
        step("Then new tab is opened and it has search text of  \(expectedSearchTextPart1) and \(expectedSearchTextPart2)") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertTrue(webView.waitForTabTitleToContain(index: 1, expectedString: expectedSearchTextPart1))
            XCTAssertTrue(webView.waitForTabTitleToContain(index: 1, expectedString: expectedSearchTextPart2))
        }
    }
    
    func testRightClickCopyText() throws {
        testrailId("C847")
        step("When I copy text") {
            rightClickMenuTestView.clickTextMenu(.copyText)
        }
        
        step("Then link has been copied") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            _ = omniboxTestView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            shortcutHelper.shortcutActionInvoke(action: .paste)

            XCTAssertEqual(omniboxTestView.getSearchFieldValue(), "beam")
        }
    }
    
    func testShareText() throws {
        testrailId("C848")
        step("When I want to share text") {
            rightClickMenuTestView.clickCommonMenu(.share)
        }
        
        step("Then Share options are displayed") {
            XCTAssertTrue(rightClickMenuTestView.isShareCommonMenuDisplayed())
        }
    }
    
    func testSpeechText() throws {
        testrailId("C849")
        step("When I want to speech text") {
            rightClickMenuTestView.clickTextMenu(.speech)
        }
        
        step("Then Speech options are displayed") {
            XCTAssertTrue(rightClickMenuTestView.isSpeechMenuDisplayed())
        }
    }
    
    func testInspectElementText() throws {
        testrailId("C851")
        step("When I want to inspect element") {
            rightClickMenuTestView.clickCommonMenu(.inspectElement)
        }
        
        step("Then Developer Menu is opened") {
            XCTAssertTrue(app.webViews.tabs["Elements"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testServicesText() throws {
        testrailId("C850")
        step("When I want to use services") {
            rightClickMenuTestView.clickTextMenu(.services)
        }
        
        step("Then Services options are displayed") {
            XCTAssertTrue(rightClickMenuTestView.isServiceMenuDisplayed())
        }
    }
}
