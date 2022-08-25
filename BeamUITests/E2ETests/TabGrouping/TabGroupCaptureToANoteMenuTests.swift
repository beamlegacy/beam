//
//  TabGroupCaptureToANoteMenuTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 16/08/2022.
//

import Foundation
import XCTest

class TabGroupCaptureToANoteMenuTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let omniboxView = OmniBoxTestView()
    let allNotesView = AllNotesTestView()
    let noteView = NoteTestView()
    
    let tabGroupNameSuffix = " & 3 more"
    
    override func setUp() {
        step("Given I have a captured group in a note") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            captureGroupToNoteAndOpenNote()
        }
    }
    
    func testRenameCapturedTabGroup() throws {
        testrailId("C1026")
        step("When I open the captured tab group menu") {
            noteView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
        }

        step("Then I can rename the captured tab group") {
            tabGroupMenu.renameExistingTabGroupName(tabGroupName: "Renamed Captured")
            XCTAssertEqual(noteView.getTabGroupElementName(index: 0), "Renamed Captured tab group")
        }
    }
    
    func testOpenInBackgroundCapturedTabGroup() throws {
        testrailId("C1028")
        let tabTitles = [
            uiTestPageOne,
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageFour
        ]
        
        step("When I open the captured tab group in background") {
            noteView.openTabGroupMenu(index: 0)
                .clickTabGroupMenu(.tabGroupOpenInBackground)
        }

        step("Then tabs are reopened in background") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), uiTestPageOne + tabGroupNameSuffix)
            XCTAssertTrue(webView.areTabsInCorrectOrder(tabs: tabTitles))
        }
    }
    
    func testOpenInNewWindowCapturedTabGroup() throws {
        testrailId("C1029")
        step("When I open the captured tab group in new window") {
            noteView.openTabGroupMenu(index: 0)
                .clickTabGroupMenu(.tabGroupOpenInNewWindow)
        }

        step("Then tabs are opened in a new window") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(getNumberOfWindows(), 2)
            XCTAssertEqual(getNumberOfTabInWindowIndex(index: 0), 4)
            XCTAssertEqual(noteView.getTabGroupNameOfWindow(index: 0), uiTestPageOne + tabGroupNameSuffix)
        }
    }
    
    func testDeleteCapturedTabGroup() throws {
        testrailId("C1030")
        step("When I delete the captured tab group from note") {
            noteView.openTabGroupMenu(index: 0)
                .clickTabGroupMenu(.tabGroupDeleteGroup)
        }

        step("Then tab group is deleted") {
            XCTAssertFalse(noteView.isTabGroupDisplayed(index: 0))
        }
        
        step("And is not display in omnibox anymore") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            let results = omniboxView.getAutocompleteResults()
            for result in results {
                XCTAssertNotEqual(result.getStringValue(), uiTestPageOne + tabGroupNameSuffix)
            }
        }
    }
}
