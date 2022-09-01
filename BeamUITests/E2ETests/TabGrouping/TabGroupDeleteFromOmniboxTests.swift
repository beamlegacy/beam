//
//  TabGroupDeleteFromOmniboxTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 01/09/2022.
//

import Foundation
import XCTest

class TabGroupDeleteFromOmniboxTests: BaseTest {
    
    let noteView = NoteTestView()
    let omniboxView = OmniBoxTestView()
    let dialogView = DialogTestView()
    let tabGroupNamed = "Test1"
    
    func testTabGroupDeleteCapturedNotShared() throws {
        testrailId("C1174")
        let noteTitle = DateHelper().getTodaysDateString(.noteViewTitle)
        step("Given I have a captured group in a note") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroupNamed()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            captureGroupToNoteAndOpenNote()
        }
        
        step("When I open tab group in omnibox") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            omniboxView.selectAutocompleteResult(autocompleteResult: tabGroupNamed)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
        }
        
        step("Then I have the option to delete the tab group") {
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.deleteTabGroup.accessibilityIdentifier))
        }
        
        step("When I click to delete tab group") {
            omniboxView.deleteTabGroup()
        }
        
        step("Then confirmation pop up is displayed") {
            XCTAssertTrue(dialogView.isDeleteTabGroupAlertDisplayed(tabGroupName: tabGroupNamed, noteTitle: noteTitle))
        }
        
        step("When I cancel to delete tab group") {
            dialogView.getButton(locator: .cancelButton).tapInTheMiddle()
        }
        
        step("Then tab group is not deleted") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox) // close omnibox
            XCTAssertTrue(noteView.isTabGroupDisplayed(index: 0))
        }
        
        step("When I delete tab group") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            omniboxView.selectAutocompleteResult(autocompleteResult: tabGroupNamed)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.deleteTabGroup()
            dialogView.getButton(locator: .deleteButton).tapInTheMiddle()
        }
        
        step("Then tab group is deleted on note") {
            XCTAssertFalse(noteView.isTabGroupDisplayed(index: 0))
        }
        
        step("And can be forgotten") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            XCTAssertTrue(omniboxView.isTabGroupResultDisplayed(tabGroupName: tabGroupNamed))
            omniboxView.selectAutocompleteResult(autocompleteResult: tabGroupNamed)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.forgetTabGroup.accessibilityIdentifier))
        }
    }
    
}
