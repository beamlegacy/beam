//
//  RightClickPageMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 11/07/2022.
//

import Foundation
import XCTest

class RightClickPageMenuTests: BaseTest {
    var app = XCUIApplication()
    let rightClickMenuTestView = RightClickMenuTestView()
    let pageToRightClickOn = XCUIApplication().windows.webViews.firstMatch
    let linkToOpen = MockHTTPWebPages().getMockPageUrl(.ambiguousShortForm).dropLast()
    let url1 = String(MockHTTPWebPages().getMockPageUrl(.mainView).dropFirst("http://".count))
    let url2 = String(MockHTTPWebPages().getMockPageUrl(.ambiguousShortForm).dropFirst("http://".count))
    
    private func openPageByLinkClick() {
        webView.staticText(String(linkToOpen)).tapInTheMiddle()
    }
    
    private func openPageByContinueButtonClick() {
        webView.button("Continue").tapInTheMiddle()
    }
    
    private func verifyMenuForPage () {
        //wait for menu to be displayed - inspect element should always be displayed
        rightClickMenuTestView.waitForMenuToBeDisplayed()

        for item in RightClickMenuViewLocators.PageMenuItems.allCases {
            XCTAssertTrue(app.windows.menuItems[item.accessibilityIdentifier].exists)
        }
        XCTAssertFalse(app.windows.menuItems["Services"].exists)
        XCTAssertFalse(app.windows.menuItems[RightClickMenuViewLocators.CommonMenuItems.share.accessibilityIdentifier].exists)

    }
    
    override func setUp() {
        step("Given I open multiple web pages in the same tab"){
            launchApp()
            uiMenu.startMockHTTPServer()
            mockPage.openMockPage(.mainView)
            self.openPageByLinkClick()
            self.openPageByContinueButtonClick()
        }
        
        step("When I right click on page") {
            pageToRightClickOn.rightClick()
        }
        
        step("Then menu is displayed") {
            verifyMenuForPage()
        }
    }
    
    func testRightClickPageNavigation() throws {
        let backButton = app.windows.menuItems[RightClickMenuViewLocators.PageMenuItems.back.accessibilityIdentifier]
        let forwardButton = app.windows.menuItems[RightClickMenuViewLocators.PageMenuItems.forward.accessibilityIdentifier]
        
        step("Then forward button is disabled and \(url2) is opened on browser history back button click"){
            XCTAssertFalse(forwardButton.isEnabled)
            XCTAssertTrue(backButton.isEnabled)
            rightClickMenuTestView.clickPageMenu(.back)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), url2)
        }

        step("When I right click on page") {
            pageToRightClickOn.rightClick()
        }
        
        step("THEN Back and Forward buttons are enabled"){
            XCTAssertTrue(forwardButton.isEnabled)
            XCTAssertTrue(backButton.isEnabled)
        }
        
        step("And \(url1) is opened on Back"){
            rightClickMenuTestView.clickPageMenu(.back)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), url1)
        }
        
        step("When I right click on page") {
            pageToRightClickOn.rightClick()
        }
        
        step("Then Back button is disabled and Forward button is enabled"){
            XCTAssertTrue(forwardButton.isEnabled)
            XCTAssertFalse(backButton.isEnabled)
            webView.typeKeyboardKey(.escape) //disable menu
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), url1)

        }

    }
    
    func testRightClickPageReload() throws {
        
        step("When I click on Reload page"){
            rightClickMenuTestView.clickPageMenu(.reloadPage)
        }

        step("Then page is reloaded") {
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), url2 + "view")
        }
    }
    
    func testRightClickCopyPageAddress() throws {

        step("When I want to copy page address") {
            rightClickMenuTestView.clickPageMenu(.copyPageAddress)
        }
        
        step("Then page address has been copied") {
            let noteView = NoteTestView()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
            let noteNodes = noteView.getNoteNodesForVisiblePart()
            noteNodes[0].tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .paste)
            XCTAssertEqual(noteNodes[0].getStringValue(), "http://" + url2 + "view")
        }
    }
    
    func testRightClickPrintPage() throws {

        step("When I want to print page") {
            rightClickMenuTestView.clickPageMenu(.printPage)
        }
        
        step("Then Print Menu is opened") {
            XCTAssertTrue(app.windows.buttons["Print"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testInspectElementPage() throws {

        step("When I want to inspect page") {
            rightClickMenuTestView.clickPageMenu(.inspectElement)
        }
        
        step("Then Developer Menu is opened") {
            XCTAssertTrue(app.webViews.tabs["Elements"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
