//
//  TabGroupCaptureToANoteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 28/07/2022.
//

import Foundation
import XCTest

class TabGroupCaptureToANoteTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let noteView = NoteTestView()
    
    func testUnnamedTabGroupCapture() throws {
        
        step("Given I have one tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("When I capture the tab group") {
            tabGroupMenu.openTabGroupMenu(index: 0)
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCapture)
            tabGroupMenu.typeKeyboardKey(.enter)
            tabGroupMenu.typeKeyboardKey(.escape)
        }
        
        step("Then tab group is captured on note") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            AllNotesTestView().openFirstNote()
            XCTAssertTrue(noteView.isTabGroupDisplayed(index: 0))
            XCTAssertEqual(noteView.getTabGroupElementName(index: 0), "Point And Shoot Test Fixture Ultralight Beam & 3 more tab group")
        }

        step("When I close the tab group") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            tabGroupMenu.closeTabGroup(index: 0)
            XCTAssertTrue(noteView.waitForTodayNoteViewToLoad())
        }


        step("Then I can reopen tab group through note") {
            noteView.openTabGroup(index: 0)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(),4)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "Point And Shoot Test Fixture Ultralight Beam & 3 more")
        }
        
    }
    
    func testNamedTabGroupCapture() throws {
        
        step("Given I have one tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroupNamed()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("When I capture the tab group") {
            tabGroupMenu.openTabGroupMenu(index: 0)
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCapture)
            tabGroupMenu.typeKeyboardKey(.enter)
            tabGroupMenu.typeKeyboardKey(.escape)
        }
        
        step("Then tab group is captured on note") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            AllNotesTestView().openFirstNote()
            XCTAssertTrue(noteView.isTabGroupDisplayed(index: 0))
            XCTAssertEqual(noteView.getTabGroupElementName(index: 0), "Test1 tab group")
        }

        step("When I close the tab group") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            tabGroupMenu.closeTabGroup(index: 0)
            XCTAssertTrue(noteView.waitForTodayNoteViewToLoad())
        }

        step("Then I can reopen tab group through note") {
            noteView.openTabGroup(index: 0)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(),4)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "Test1")
        }
    }
    
    func testTabGroupMultipleCapture() throws {
        
        step("Given I have one tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("When I capture the tab group") {
            tabGroupMenu.captureTabGroup(index: 0)
        }
        
        step("And I capture the tab group with different name") {
            tabGroupMenu.openTabGroupMenu(index: 0)
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.setTabGroupName(tabGroupName: "E2E Test")
            tabGroupMenu.captureTabGroup(index: 0)
        }
        
        step("Then both tab groups are captured") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            AllNotesTestView().openFirstNote()
            XCTAssertEqual(noteView.getTabGroupCount(), 2)
            XCTAssertEqual(noteView.getTabGroupElementName(index: 0), "E2E Test tab group")
            XCTAssertEqual(noteView.getTabGroupElementName(index: 1), "Point And Shoot Test Fixture Ultralight Beam & 3 more tab group")
        }

    }
}
