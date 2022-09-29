//
//  BrowserVideoSideWindowPreferencesTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 29/09/2022.
//

import Foundation
import XCTest

class BrowserVideoSideWindowPreferencesTests: BaseTest {
    
    let browserPref = BrowserPreferencesTestView()
    let omnibox = OmniBoxTestView()
    let conferenceDialog = XCUIApplication().dialogs.firstMatch
    
    func testVideoCallsAlwaysOpen() {
        testrailId("C1189")
        let expectedCheckboxTitle = "Always open in side window"
        
        step ("GIVEN I open Browser preferences"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .browser)
            browserPref.waitForViewToLoad()
        }
        
        step("WHEN I disable Video call side window checkbox that has title: \(expectedCheckboxTitle)") {
            XCTAssertEqual(browserPref.getVideoCallSideWindowCheckbox().title, expectedCheckboxTitle)
            browserPref.getVideoCallSideWindowCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSetDefaultButton())
        }
        
        step("THEN video call opens in tab in tab") {
            OmniBoxTestView().openWebsite(meetingTestUrl)
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertFalse(conferenceDialog.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testVideoCallsNotAlwaysOpen() {
        testrailId("C1189")

        step("WHEN I open a video call url") {
            OmniBoxTestView().openWebsite(meetingTestUrl)
        }
        
        step("THEN video call opens in tab in side window by default") {
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
            XCTAssertTrue(conferenceDialog.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
        
}
