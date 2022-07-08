//
//  RightClickLinkMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 08/07/2022.
//

import Foundation
import XCTest

class RightClickLinkMenuTests: BaseTest {
    let pageTitle = "Point And Shoot Test Fixture I-Beam"
    let linkToRightClickOn = WebTestView().staticText("structural steel")
    let linkName = "Structural_steel"
    let rightClickMenuTestView = RightClickMenuTestView()
    let downloadsView = DownloadTestView()
    let omniboxTestView = OmniBoxTestView()

    var app = XCUIApplication()

    private func verifyShareMenuForLink () {
        rightClickMenuTestView.waitForShareMenuToBeDisplayed()
        
        for item in RightClickMenuViewLocators.ShareCommonMenuItems.allCases {
            XCTAssertTrue(app.menuItems[item.accessibilityIdentifier].exists)
        }
    }
    
    private func verifyMenuForLink () {
        //wait for menu to be displayed - inspect element should always be displayed
        rightClickMenuTestView.waitForMenuToBeDisplayed()

        for item in RightClickMenuViewLocators.LinkMenuItems.allCases {
            XCTAssertTrue(app.menuItems[item.accessibilityIdentifier].exists)
        }
        for item in RightClickMenuViewLocators.CommonMenuItems.allCases {
            XCTAssertTrue(app.menuItems[item.accessibilityIdentifier].exists)
        }
    }
        
    override func setUp() {
        step("Given I start mock server") {
            launchApp()
            uiMenu.loadUITestPage2()
        }
        
        step("When I right click on an image") {
            linkToRightClickOn.rightClick()
        }
        
        step("Then menu is displayed") {
            verifyMenuForLink()
        }
    }
    
    func testRightClickOpenNewTabLink() throws {
        
        step("When I open link in a new tab") {
            rightClickMenuTestView.clickLinkMenu(.openLinkInNewTab)
        }
        
        step("Then link is correctly opened in a new tab") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), pageTitle)
            _ = webView.focusTabByIndex(index: 0)
            // URL will be displayed on focus only if tab is the one used - URL without prefix http
            // It means the image is opened in a new tab which is not directly displayed to the user
            XCTAssertTrue(webView.getTabUrlAtIndex(index: 0).contains("Resources/UITests-2.html"))
        }
    }
    
    func testRightClickOpenNewWindowLink() throws {
        
        step("When I open link in a new window") {
            rightClickMenuTestView.clickLinkMenu(.openLinkInNewWindow)
        }
        
        step("Then link is correctly opened in a new window") {
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }
    }
    
    func testRightClickLinkDownloadLinkedFile() throws {

        step("When I download linked file") {
            rightClickMenuTestView.clickLinkMenu(.downloadLinkedFile)
        }
        
        step("Then linked file is downloaded") {
            omniboxTestView.openDownloadsView()
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(downloadsView.isDownloadedFileDisplayed(fileToSearch: linkName))
        }
    }
    
    func testRightClickLinkDownloadLinkedFileAs() throws {

        step("When I save link to another location") {
            rightClickMenuTestView.clickLinkMenu(.downloadLinkedFileAs)
        }

        step("Then link download locator window is displayed") {
            _ = app.textFields[linkName].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            XCTAssertTrue(app.textFields[linkName].exists)
            XCTAssertTrue(app.buttons["Save"].exists)
            XCTAssertTrue(app.buttons["Cancel"].exists)
        }
    }
    
    func testRightClickCopyLink() throws {

        step("When I copy link") {
            rightClickMenuTestView.clickLinkMenu(.copyLink)
        }
        
        step("Then link has been copied") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            shortcutHelper.shortcutActionInvoke(action: .paste)

            XCTAssertEqual(omniboxTestView.getSearchFieldValue(), "file:///wiki/Structural_steel")
        }
    }
    
    func testShareLink() throws {

        step("When I want to share link") {
            rightClickMenuTestView.clickCommonMenu(.share)
        }
        
        step("Then Share options are displayed") {
            verifyShareMenuForLink()
        }
    }
    
    func testInspectElementImage() throws {

        step("When I want to inspect element") {
            rightClickMenuTestView.clickCommonMenu(.inspectElement)
        }
        
        step("Then Developer Menu is opened") {
            XCTAssertTrue(app.webViews.tabs["Elements"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
