//
//  DownloadsTest.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class DownloadsTest: BaseTest {
    
    let downloadLink = "devimages-cdn.apple.com/design/resources/download/SF-Symbols-3.dmg"

    func testDownloadView() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        testRailPrint("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBar(downloadLink, true)
        let omniBarView = OmniBarTestView()
        let downloadsView = omniBarView.openDownloadsView()
        
        testRailPrint("Then downloads view shows corerctlabels and buttons")
        if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
            journalView.searchInOmniBar(downloadLink, true)
            omniBarView.openDownloadsView()
        }
        XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.viewInFinderButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).exists)
        
        testRailPrint("When I stop downloading process")
        downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        testRailPrint("Then resume download button exists and stop download button doesn't exist")
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        
        //"Temp solution to fix the false failure to be found")
        /*testRailPrint("When I resume download process")
        downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).click()
        downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).click()
        testRailPrint("Then download button exists")
        XCTAssertTrue(omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)*/
    }
    
    func testClearDownload() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        testRailPrint("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBar(downloadLink, true)
        let omniBarView = OmniBarTestView()
        let downloadsView = omniBarView.openDownloadsView()
        
        testRailPrint("When I stop downloading process")
        if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
            journalView.searchInOmniBar(downloadLink, true)
            omniBarView.openDownloadsView()
        }
        downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        
        testRailPrint("Then I can see Clear button available")
        XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I click Clear button")
        downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).click()
        
        testRailPrint("Then Downloads option is unavailable anymore")
        WaitHelper().waitFor(WaitHelper.PredicateFormat.notExists.rawValue, omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier))
        XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
        XCTAssertFalse(omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
}
