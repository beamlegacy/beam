//
//  RightClickImageMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/07/2022.
//

import Foundation
import XCTest

class RightClickImageMenuTests: BaseTest {
    
    let pageTitle = "Point And Shoot Test Fixture I-Beam"
    let imageName = "800px-Beam_mode_2.gif"
    let imageToRightClickOn = WebTestView().image("File:Beam mode 2.gif")
    let rightClickMenuTestView = RightClickMenuTestView()
    
    var app = XCUIApplication()
    private var helper: BeamUITestsHelper!

    override func setUp() {
        step("Given I open test page") {
            helper = BeamUITestsHelper(launchApp().app)
            uiMenu.loadUITestPage2()
        }
        
        step("When I right click on an image") {
            imageToRightClickOn.rightClick()
        }
        
        step("Then menu is displayed") {
            verifyMenuForImage()
        }
    }
    
    private func verifyShareMenuForImage () {
        rightClickMenuTestView.waitForShareMenuToBeDisplayed()
        
        for item in RightClickMenuViewLocators.ShareImageMenuItems.allCases {
            XCTAssertTrue(app.windows.menuItems[item.accessibilityIdentifier].exists)
        }
        XCTAssertTrue(rightClickMenuTestView.isShareCommonMenuDisplayed())
    }
    
    private func verifyMenuForImage () {
        //wait for menu to be displayed - inspect element should always be displayed
        rightClickMenuTestView.waitForMenuToBeDisplayed()

        for item in RightClickMenuViewLocators.ImageMenuItems.allCases {
            XCTAssertTrue(app.windows.menuItems[item.accessibilityIdentifier].exists)
        }
        for item in RightClickMenuViewLocators.CommonMenuItems.allCases {
            XCTAssertTrue(app.windows.menuItems[item.accessibilityIdentifier].exists)
        }
        XCTAssertFalse(app.windows.menuItems["Services"].exists)

    }
    
    func testRightClickOpenNewTabImage() throws {
        
        step("When I open image in a new tab") {
            rightClickMenuTestView.clickImageMenu(.openImageInNewTab)
        }
        
        step("Then image is correctly opened in a new tab") {
            let imageTitle = imageName + " 800×476 pixels"
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            helper.moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), pageTitle)
            waitForStringValueEqual(imageTitle, webView.getBrowserTabTitleElements()[1])
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 1), imageTitle)
            _ = webView.focusTabByIndex(index: 0)
            // URL will be displayed on focus only if tab is the one used - URL without prefix http
            // It means the image is opened in a new tab which is not directly displayed to the user
            XCTAssertTrue(webView.getTabUrlAtIndex(index: 0).contains("Resources/UITests-2.html"))
        }
    }
    
    func testRightClickOpenNewWindowImage() throws {

        step("When I open image in a new window") {
            rightClickMenuTestView.clickImageMenu(.openImageInNewWindow)
        }
        
        step("Then image is correctly opened in a new window") {
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }
    }
    
    func testRightClickImageSaveToDownloads() throws {

        step("When I save image to downloads") {
            rightClickMenuTestView.clickImageMenu(.saveToDownloads)
        }
        
        step("Then image is correctly downloaded but download menu does not open") {
            XCTAssertTrue(waitForDoesntExist(app.buttons[ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier]))
        }
    }
    
    func testRightClickImageSaveAs() throws {

        step("When I save image to another location") {
            rightClickMenuTestView.clickImageMenu(.saveAs)
        }
        
        step("Then image download locator window is displayed") {
            _ = app.textFields[imageName].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
            XCTAssertTrue(app.textFields[imageName].exists)
            XCTAssertTrue(app.buttons["Save"].exists)
            XCTAssertTrue(app.buttons["Cancel"].exists)
        }
    }
    
    func testRightClickCopyImageAddress() throws {

        step("When I copy image address") {
            rightClickMenuTestView.clickImageMenu(.copyImageAddress)
        }
        
        step("Then image address has been copied") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            shortcutHelper.shortcutActionInvoke(action: .paste)

            XCTAssertEqual(OmniBoxTestView().getSearchFieldValue(), "https://upload.wikimedia.org/wikipedia/commons/thumb/7/76/Beam_mode_2.gif/800px-Beam_mode_2.gif")
        }
    }
    
    func testRightClickCopyImage() throws {

        step("When I copy image address") {
            rightClickMenuTestView.clickImageMenu(.copyImage)
        }
        
        step("Then image address has been copied") {
            let noteView = NoteTestView()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
            noteView.getNoteNodesForVisiblePart()[0].tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .paste)
            XCTAssertTrue(waitForCountValueEqual(timeout: noteView.minimumWaitTimeout, expectedNumber: 1, elementQuery: noteView.getImageNotesElementsQuery()), "Image didn't appear within \(noteView.minimumWaitTimeout) seconds")
        }
    }
    
    func testShareImage() throws {

        step("When I want to share image") {
            rightClickMenuTestView.clickCommonMenu(.share)
        }
        
        step("Then Share options are displayed") {
            verifyShareMenuForImage()
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
