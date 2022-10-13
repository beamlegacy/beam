//
//  TabGroupCaptureToANoteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 28/07/2022.
//

import Foundation
import XCTest

class TabGroupCaptureToANoteTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    let noteView = NoteTestView()
    let allNotesView = AllNotesTestView()
    let pnsView = PnSTestView()
    
    private func verifyTabGroupCapturedInNote (tabGroupName: String, noteName: String? = nil, indexOfTabGroup: Int = 0){        
        if let noteName = noteName {
            openNoteByTitle(noteName)
        } else {
            openTodayNote()
        }
        XCTAssertTrue(noteView.isTabGroupDisplayed(index: indexOfTabGroup))
        XCTAssertEqual(noteView.getTabGroupElementName(index: indexOfTabGroup), tabGroupName)
    }
    
    func testUnnamedTabGroupCapture() {
        testrailId("C981, C1053")
        step("Given I have one tab group") {
            createTabGroupAndSwitchToWeb()
        }
        
        step("When I capture the tab group") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupCapture)
            pnsView.waitForCollectPopUpAppear()
            pnsView.typeKeyboardKey(.enter)
            XCTAssertTrue(pnsView.assertAddedToNoteLabelDisplayed())
            pnsView.typeKeyboardKey(.escape)
        }

        testrailId("C813")
        step("Then tab group is captured on note") {
            verifyTabGroupCapturedInNote(tabGroupName: uiTestPageOne + " & 3 more tab group")
        }

        step("When I close the tab group") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            tabGroupView.closeTabGroup(index: 0)
            XCTAssertTrue(noteView.waitForTodayNoteViewToLoad())
        }

        testrailId("C1025")
        step("Then I can reopen tab group through note") {
            noteView.openTabGroup(index: 0)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(),4)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), uiTestPageOne + " & 3 more")
        }
        
    }
    
    func testNamedTabGroupCapture() throws {
        testrailId("C981, C1054")
        step("Given I have one tab group") {
            createTabGroupAndSwitchToWeb(named: true)
        }
        
        step("When I capture the tab group") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupCapture)
            pnsView.waitForCollectPopUpAppear()
            pnsView.typeKeyboardKey(.enter)
            XCTAssertTrue(pnsView.assertAddedToNoteLabelDisplayed())
            pnsView.typeKeyboardKey(.escape)
        }
        
        testrailId("C1026")
        step("Then tab group is captured on note") {
            verifyTabGroupCapturedInNote(tabGroupName: "Test1 tab group")
        }

        step("When I close the tab group") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            tabGroupView.closeTabGroup(index: 0)
            XCTAssertTrue(noteView.waitForTodayNoteViewToLoad())
        }

        step("Then I can reopen tab group through note") {
            noteView.openTabGroup(index: 0)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(),4)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "Test1")
        }
    }
    
    func testMultipleTabGroupsCapture() throws {
        testrailId("C981, C1055")
        step("Given I have one tab group") {
            createTabGroupAndSwitchToWeb()
        }
        
        step("When I capture the tab group") {
            tabGroupView.captureTabGroup(index: 0)
        }
        
        step("And I capture the tab group with different name") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: "E2E Test")
                .captureTabGroup(index: 0)
        }
        
        step("Then both tab groups are captured") {
            verifyTabGroupCapturedInNote(tabGroupName: "E2E Test tab group")
            verifyTabGroupCapturedInNote(tabGroupName: uiTestPageOne + " & 3 more tab group", indexOfTabGroup: 1)
            XCTAssertEqual(noteView.getTabGroupCount(), 2)
        }
    }
    
    func testCaptureSingleGroupToMultipleNotes() throws {
        testrailId("C1056")
        let note1 = "Test Note"
        let note2 = "Test Note 2"
        let capturedTabGroupName = "Test1 tab group"
        
        step("Given I have one tab group") {
            createTabGroupAndSwitchToWeb(named: true)
        }
        
        step("When I capture the tab group to different notes") {
            tabGroupView.captureTabGroup(index: 0, destinationNote: note1)
            tabGroupView.captureTabGroup(index: 0, destinationNote: note2)
        }
        
        step("Then tab group is saved in \(note1) and \(note2)") {
            verifyTabGroupCapturedInNote(tabGroupName: capturedTabGroupName, noteName: note1)
            verifyTabGroupCapturedInNote(tabGroupName: capturedTabGroupName, noteName: note2)
        }

    }
}
