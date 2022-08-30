//
//  TabGroupSharingFromNoteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/08/2022.
//

import Foundation
import XCTest

class TabGroupSharingFromNoteTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let allNotesView = AllNotesTestView()
    let dialogView = DialogTestView()
    let noteView = NoteTestView()
    let copyLinkAction = "Copy Link"
    let shareWithTwitterAction = "Twitter"
    
    func testShareTabGroupMenuNotLogged() throws {
        testrailId("C1171")
        step("Given I have a captured group in a note") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            captureGroupToNoteAndOpenNote()
        }
        
        step("When I open the captured tab group menu") {
            noteView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
        }
        
        step("Then Share Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupMenu.clickTabGroupMenu(.tabGroupShareGroup)
                .isShareTabMenuDisplayed())
        }
        
        step("When I Share Tab Group without being logged in") {
            tabGroupMenu.shareTabGroupAction(shareWithTwitterAction)
        }
        
        step("Then I get the connect alert message") {
            XCTAssertTrue(dialogView.isConnectTabGroupDisplayed())
        }
    }
    
    func testShareTabGroupMenu() throws {
        testrailId("C1165, C1166, C1167, C1168, C1169, C1170")
        step("Given I have a captured group in a note being logged in") {
            setupStaging(withRandomAccount: true)
            uiMenu.createTabGroup()
            captureGroupToNoteAndOpenNote()
        }
        
        let windows = ["Twitter", "Facebook", "LinkedIn", "Reddit"]
                
        for windowTitle in windows {
            if windowTitle != windows[2] { //To be removed as part of BE-5195
                step ("Then \(windowTitle) window is opened using Share option") {
                    _ = noteView.openTabGroupMenu(index: 0)
                        .clickTabGroupMenu(.tabGroupShareGroup)
                        .shareTabGroupAction(windowTitle)
                        .waitForWebViewToLoad()
                    XCTAssertTrue(waitForIntValueEqual(timeout: BaseTest.maximumWaitTimeout, expectedNumber: 2, query: getNumberOfWindows()), "Second window wasn't opened during \(BaseTest.maximumWaitTimeout) seconds timeout")
                    XCTAssertTrue(
                        webView.isWindowOpenedWithContaining(title: windowTitle) ||
                        webView.isWindowOpenedWithContaining(title: windowTitle, isLowercased: true)
                        )
                    shortcutHelper.shortcutActionInvoke(action: .close)
                }
            }
        }
    }
    
    func testShareTabGroupCopyUrlNotLogged() throws {
        testrailId("C1171, C1170")
        step("Given I have a captured group in a note") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            captureGroupToNoteAndOpenNote()
        }
        
        step("When I copy link to share tab group without being logged in") {
            clearPasteboard() // clear content of pasteboard
            noteView.openTabGroupMenu(index: 0)
                .shareTabGroupAction(copyLinkAction)
        }
        
        step("Then I get the connect alert message") {
            XCTAssertTrue(dialogView.isConnectTabGroupDisplayed())
        }
        
        step("And nothing has been copied in pasteboard") {
            XCTAssertTrue(isPasteboardEmpty())
        }
    }
    
    func testShareTabGroupCopyUrl() throws {
        testrailId("C1171, C1170")
        step("Given I have a captured group in a note being logged in") {
            setupStaging(withRandomAccount: true)
            uiMenu.createTabGroup()
            captureGroupToNoteAndOpenNote()
        }
        
        step("When I copy link of tab to share tab group") {
            clearPasteboard() // clear content of pasteboard
            noteView.openTabGroupMenu(index: 0)
                .shareTabGroupAction(copyLinkAction)
        }
        
        step("Then short tab group link is copied to pasteboard") {
            XCTAssertTrue(webView.staticText(TabGroupMenuViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            XCTAssertEqual(getNumberOfPasteboardItem(), 1)
            XCTAssertTrue(tabGroupMenu.isTabGroupLinkInPasteboard())
        }
        
        step("And short link URL redirect to full link URL") {
            let omniboxTestView = OmniBoxTestView()
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            shortcutHelper.shortcutActionInvoke(action: .paste)
            webView.typeKeyboardKey(.enter)
            webView.waitForWebViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            _ = omniboxTestView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            XCTAssertTrue(tabGroupMenu.isMatchingFullURL(omniboxTestView.getSearchFieldValue()))
        }
    }
}
