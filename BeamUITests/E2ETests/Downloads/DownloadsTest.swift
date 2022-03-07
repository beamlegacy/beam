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

    func SKIPtestDownloadView() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        testRailPrint("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBox(downloadLink, true)
        let omniBoxView = OmniBoxTestView()
        let downloadsView = omniBoxView.openDownloadsView()
        
        testRailPrint("Then downloads view shows corerctlabels and buttons")
        if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
            journalView.searchInOmniBox(downloadLink, true)
            omniBoxView.openDownloadsView()
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
        XCTAssertTrue(omniBoxView.button(OmniBoxLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)*/
    }
    
    func SKIPtestClearDownload() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        testRailPrint("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBox(downloadLink, true)
        let omniBoxView = OmniBoxTestView()
        let downloadsView = omniBoxView.openDownloadsView()
        
        testRailPrint("When I stop downloading process")
        if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
            journalView.searchInOmniBox(downloadLink, true)
            omniBoxView.openDownloadsView()
        }
        downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        
        testRailPrint("Then I can see Clear button available")
        XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I click Clear button")
        downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).click()
        
        testRailPrint("Then Downloads option is unavailable anymore")
        WaitHelper().waitFor(WaitHelper.PredicateFormat.notExists.rawValue, omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier))
        XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
        XCTAssertFalse(omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
    }
}
