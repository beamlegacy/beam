//
//  TabGroupSharingFromBrowserTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/08/2022.
//

import Foundation
import XCTest

class TabGroupSharingFromBrowserTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let dialogView = DialogTestView()
    let tabGroupNameSharing = "Sharing..."
    
    private func createTabGroupOnStaging(){
        step("Given I open Share Tab Group Menu being logged in") {
            signUpStagingWithRandomAccount()
            createTabGroupAndSwitchToWeb()
            tabGroupMenu.openTabGroupMenu(index: 0)
                .clickTabGroupMenu(.tabGroupShareGroup)
        }
    }
    
    private func createTabGroupWithoutBeingLogged(){
        step("Given I open Share Tab Group Menu without being logged in") {
            createTabGroupAndSwitchToWeb()
            tabGroupMenu.openTabGroupMenu(index: 0)
                .clickTabGroupMenu(.tabGroupShareGroup)
        }
    }
    
    func testShareTabGroupMenuNotLogged() throws {
        testrailId("C1171")
        createTabGroupWithoutBeingLogged()
        
        step("When I Share Tab Group without being logged in") {
            tabGroupMenu.shareTabGroupAction("Twitter")
        }
        
        step("Then I get the connect alert message") {
            XCTAssertTrue(dialogView.isConnectTabGroupDisplayed())
        }
    }
    
    func testShareTabGroupMenu() throws {
        testrailId("C1165, C1166, C1167, C1168, C1169, C1170")
        createTabGroupOnStaging()
        
        step("Then Share Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupMenu.isShareTabMenuDisplayed())
            webView.typeKeyboardKey(.escape) // close tab group menu
        }
        
        let windows = ["Twitter", "Facebook", "LinkedIn", "Reddit"]
                
        for windowTitle in windows {
            if windowTitle != windows[2] { //To be removed as part of BE-5195
                step ("And \(windowTitle) window is opened using Share option") {
                    _ = tabGroupMenu.openTabGroupMenu(index: 0)
                        .clickTabGroupMenu(.tabGroupShareGroup)
                        .shareTabGroupAction(windowTitle)
                        .waitForWebViewToLoad()
                    XCTAssertTrue(waitForQueryCountEqual(timeout: BaseTest.maximumWaitTimeout, expectedNumber: 2, query: getWindowsQuery()), "Second window wasn't opened during \(BaseTest.maximumWaitTimeout) seconds timeout")
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
        createTabGroupWithoutBeingLogged()
        
        step("When I copy link of tab to share tab group without being logged in") {
            clearPasteboard() // clear content of pasteboard
            tabGroupMenu.shareTabGroupAction(copyLinkShareAction)
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
        createTabGroupOnStaging()
        
        step("When I copy link of tab to share tab group") {
            clearPasteboard() // clear content of pasteboard
            tabGroupMenu.shareTabGroupAction(copyLinkShareAction)
        }
        
        step("Then tab group link is copied to pasteboard") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), tabGroupNameSharing)
            XCTAssertTrue(webView.staticText(TabGroupMenuViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            XCTAssertEqual(getNumberOfPasteboardItem(), 1)
            XCTAssertTrue(tabGroupMenu.isTabGroupLinkInPasteboard())
        }
    }

}
