//
//  TabGroupDeleteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 01/09/2022.
//

import Foundation
import XCTest

class TabGroupDeleteTests: BaseTest {
    
    let noteView = NoteTestView()
    let omniboxView = OmniBoxTestView()
    let dialogView = DialogTestView()
    let tabGroupView = TabGroupView()
    let tabGroupNamed = "Test1"
    
    private func setUpSharedNotCapturedTabGroup() {
        signUpStagingWithRandomAccount()
        createTabGroupAndSwitchToWeb(named: true)
        tabGroupView.openTabGroupMenu(index: 0)
            .clickTabGroupMenu(.tabGroupShareGroup)
            .shareTabGroupAction(copyLinkShareAction)
        XCTAssertTrue(webView.staticText(TabGroupMenuViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
    }
    
    private func setUpCapturedNotSharedTabGroup() {
        createTabGroupAndSwitchToWeb(named: true)
        captureGroupToNoteAndOpenNote()
    }
    
    private func displayTabGroupInOmnibox() {
        shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
        omniboxView.searchInOmniBox(tabGroupNamed, false)
        XCTAssertTrue(omniboxView.isTabGroupResultDisplayed(tabGroupName: tabGroupNamed))
        omniboxView.selectAutocompleteResult(autocompleteResult: tabGroupNamed)
        XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
    }
    
    private func deleteTabGroupFromOmnibox(captured: Bool, shouldBeVisibleInBrowser: Bool = true) {
        
        let noteTitle = DateHelper().getTodaysDateString(.noteViewTitle)

        step("When I open tab group in omnibox") {
            displayTabGroupInOmnibox()
        }
        
        step("Then I have the option to delete the tab group") {
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.deleteTabGroup.accessibilityIdentifier))
        }
        
        step("When I click to delete tab group") {
            omniboxView.deleteTabGroup()
        }
        step("Then confirmation pop up is displayed") {
            captured ? XCTAssertTrue(dialogView.isDeleteTabGroupAlertDisplayed(tabGroupName: tabGroupNamed, captured: captured, noteTitle: noteTitle)) : XCTAssertTrue(dialogView.isDeleteTabGroupAlertDisplayed(tabGroupName: tabGroupNamed, captured: captured))
        }
        
        step("When I cancel to delete tab group") {
            dialogView.getButton(locator: .cancelButton).tapInTheMiddle()
        }
        
        step("Then tab group is not deleted") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox) // close omnibox
            captured ? XCTAssertTrue(noteView.isTabGroupDisplayed(index: 0)) : XCTAssertTrue(tabGroupView.isTabGroupDisplayed(index: 0))
        }
        
        step("When I delete tab group") {
            displayTabGroupInOmnibox()
            omniboxView.deleteTabGroup()
            dialogView.getButton(locator: .deleteButton).tapInTheMiddle()
        }
        
        if captured {
            step("Then tab group is deleted on note") {
                XCTAssertFalse(noteView.isTabGroupDisplayed(index: 0))
            }
        } else if shouldBeVisibleInBrowser {
            step("Then tab group is not deleted on browser") {
                XCTAssertTrue(tabGroupView.isTabGroupDisplayed(index: 0))
            }
        } else {
            step("Then tab group is deleted on browser") {
                XCTAssertFalse(tabGroupView.isTabGroupDisplayed(index: 0))
            }
        }
        
    }
    
    func testTabGroupDeleteCapturedNotShared() throws {
        testrailId("C1174")

        step("Given I have a captured group in a note") {
            setUpCapturedNotSharedTabGroup()
        }
        
        deleteTabGroupFromOmnibox(captured: true)
        
        step("And can now be forgotten") {
            displayTabGroupInOmnibox()
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.forgetTabGroup.accessibilityIdentifier))
        }
    }
    
    func testTabGroupDeleteCapturedShared() throws {
        testrailId("C1175")

        step("Given I have a shared captured group in a note") {
            setUpSharedNotCapturedTabGroup()
            captureGroupToNoteAndOpenNote()
        }
        
        deleteTabGroupFromOmnibox(captured: true)
        
        step("And can still be deleted because still shared") {
            displayTabGroupInOmnibox()
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.deleteTabGroup.accessibilityIdentifier))
        }
    }
    
    func testTabGroupDeleteNotCapturedShared() throws {
        testrailId("C1178")

        step("Given I have a shared tab group") {
            setUpSharedNotCapturedTabGroup()
        }
        
        deleteTabGroupFromOmnibox(captured: false, shouldBeVisibleInBrowser: false)
        
        step("And original group has been deleted") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            XCTAssertFalse(omniboxView.isTabGroupResultDisplayed(tabGroupName: tabGroupNamed))
        }
    }
    
    func testTabGroupDeleteSharedFromNote() throws {
        testrailId("C1177")
        
        step("Given I have a shared captured group in a note") {
            setUpSharedNotCapturedTabGroup()
            captureGroupToNoteAndOpenNote()
        }
                
        step("When I delete tab groups from right click menu") {
            noteView.openTabGroupMenu(index: 0)
                .deleteTabGroupFromNoteAction()
        }
        
        step("Then tab group is deleted on note") {
            XCTAssertFalse(noteView.isTabGroupDisplayed(index: 0))
        }
        
        step("And can still be deleted because still shared") {
            displayTabGroupInOmnibox()
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.deleteTabGroup.accessibilityIdentifier))
        }
    }
    
    func testTabGroupDeleteNoteSharedFromNote() throws {
        testrailId("C1176")
        
        step("Given I have a captured group in a note") {
            setUpCapturedNotSharedTabGroup()
        }
                
        step("When I delete tab groups from right click menu") {
            noteView.openTabGroupMenu(index: 0)
                .deleteTabGroupFromNoteAction()
        }
        
        step("Then tab group is deleted on note") {
            XCTAssertFalse(noteView.isTabGroupDisplayed(index: 0))
        }
        
        step("And can now be forgotten") {
            displayTabGroupInOmnibox()
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.forgetTabGroup.accessibilityIdentifier))
        }
    }
    
}
