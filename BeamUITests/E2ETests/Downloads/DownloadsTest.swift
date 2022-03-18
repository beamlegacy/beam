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
    let omniBoxView = OmniBoxTestView()

    func SKIPtestDownloadView() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        step("Given I start downloading process using \(downloadLink) link"){
            journalView.searchInOmniBox(downloadLink, true)
        }
        let downloadsView = omniBoxView.openDownloadsView()
        
        step("Then downloads view shows corerctlabels and buttons"){
            if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
                journalView.searchInOmniBox(downloadLink, true)
                omniBoxView.openDownloadsView()
            }
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.viewInFinderButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
            XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).exists)
        }

        step("When I stop downloading process"){
            downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        }
        
        step("Then resume download button exists and stop download button doesn't exist"){
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
            XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        }
    }
    
    func SKIPtestClearDownload() throws {
        try XCTSkipIf(true, "WIP on the false failure with downloading 200 MB is few seconds. Mock is needed")
        let journalView = launchApp()
        
        step("Given I start downloading process using \(downloadLink) link"){
            journalView.searchInOmniBox(downloadLink, true)
        }
        let downloadsView = omniBoxView.openDownloadsView()
        
        step("When I stop downloading process"){
            if !downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
                journalView.searchInOmniBox(downloadLink, true)
                omniBoxView.openDownloadsView()
            }
            downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        }

        step("Then I can see Clear button available"){
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        }
        
        step("When I click Clear button"){
            downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).click()
        }
        
        step("Then Downloads option is unavailable anymore"){
            WaitHelper().waitFor(WaitHelper.PredicateFormat.notExists.rawValue, omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier))
            XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
            XCTAssertFalse(omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
        }

    }
}
