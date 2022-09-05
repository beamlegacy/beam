//
//  RightClickImageMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 06/07/2022.
//

import Foundation
import XCTest

class RightClickImageMenuTests: BaseTest {
    
    let imageName = "800px-Beam_mode_2.gif"
    let imageToRightClickOn = WebTestView().image("File:Beam mode 2.gif")
    let rightClickMenuTestView = RightClickMenuTestView()
    let omniboxTestView = OmniBoxTestView()
    
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
    
    private func verifyDownloadLocatorWindow(imageName: String, imageExtension: String = ".jpg"){
        _ = app.textFields[imageName].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        XCTAssertTrue(app.textFields[imageName].exists || app.textFields[imageName + imageExtension].exists)
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
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
        testrailId("C830")
        step("When I open image in a new tab") {
            rightClickMenuTestView.clickImageMenu(.openImageInNewTab)
        }
        
        step("Then image is correctly opened in a new tab") {
            let imageTitle = imageName + " 800×476 pixels"
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            helper.moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), uiTestPageTwo)
            waitForStringValueEqual(imageTitle, webView.getBrowserTabTitleElements()[1])
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 1), imageTitle)
            _ = webView.focusTabByIndex(index: 0)
            // URL will be displayed on focus only if tab is the one used - URL without prefix http
            // It means the image is opened in a new tab which is not directly displayed to the user
            XCTAssertTrue(webView.getTabUrlAtIndex(index: 0).contains("Resources/UITests-2.html"))
        }
    }
    
    func testRightClickOpenNewWindowImage() throws {
        testrailId("C831")
        step("When I open image in a new window") {
            rightClickMenuTestView.clickImageMenu(.openImageInNewWindow)
        }
        
        step("Then image is correctly opened in a new window") {
            XCTAssertEqual(getNumberOfWindows(), 2)
        }
    }
    
    func testRightClickImageSaveToDownloads() throws {
        testrailId("C832")
        step("When I save image to downloads") {
            rightClickMenuTestView.clickImageMenu(.saveToDownloads)
        }
        
        step("Then image is correctly downloaded but download menu does not open") {
        }
        
        step("When I open an image from raw URL") {
            uiMenu.startMockHTTPServer()
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            mockPage.openMockPage(.jpgFile)
        }
        
        step("Then I can save image to Downloads without crash") { // BE-5413
            app.webViews.children(matching: .image).element.rightClick()
            rightClickMenuTestView.clickImageMenu(.saveToDownloads)
            XCTAssertTrue(waitForDoesntExist(app.buttons[ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier]))
            XCTAssertEqual(webView.getNumberOfTabs(), 1) // beam still opened in the tab
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), mockPage.getMockPageUrl(.jpgFile).replacingOccurrences(of: "http://www.", with: "")) // beam still opened in the tab
        }
    }
    
    func testRightClickImageSaveAs() throws {
        testrailId("C833")
        step("When I save image to another location") {
            rightClickMenuTestView.clickImageMenu(.saveAs)
        }
        
        step("Then image download locator window is displayed") {
            verifyDownloadLocatorWindow(imageName: imageName)
            webView.typeKeyboardKey(.escape)
        }
        
        step("When I open an image from raw URL") {
            uiMenu.startMockHTTPServer()
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            mockPage.openMockPage(.jpgFile)
        }
        
        step("Then image download locator window is displayed") { // BE-5413
            app.webViews.children(matching: .image).element.rightClick()
            rightClickMenuTestView.clickImageMenu(.saveAs)
            verifyDownloadLocatorWindow(imageName: "slow_bart_simpson")
        }
    }
    
    func testRightClickCopyImageAddress() throws {
        testrailId("C834")
        step("When I copy image address") {
            rightClickMenuTestView.clickImageMenu(.copyImageAddress)
        }
        
        step("Then image address has been copied") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            _ = omniboxTestView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            shortcutHelper.shortcutActionInvoke(action: .paste)

            XCTAssertEqual(omniboxTestView.getSearchFieldValue(), "https://upload.wikimedia.org/wikipedia/commons/thumb/7/76/Beam_mode_2.gif/800px-Beam_mode_2.gif")
        }
    }
    
    func testRightClickCopyImage() throws {
        testrailId("C835")
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
        testrailId("C836")
        step("When I want to share image") {
            rightClickMenuTestView.clickCommonMenu(.share)
        }
        
        step("Then Share options are displayed") {
            verifyShareMenuForImage()
        }
    }
    
    func testInspectElementImage() throws {
        testrailId("C851")
        step("When I want to inspect element") {
            rightClickMenuTestView.clickCommonMenu(.inspectElement)
        }
        
        step("Then Developer Menu is opened") {
            XCTAssertTrue(app.webViews.tabs["Elements"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
