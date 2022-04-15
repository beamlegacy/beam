//
//  DownloadsTest.swift
//  BeamUITests
//
//  Created by Andrii on 03.08.2021.
//

import Foundation
import XCTest

class DownloadsTest: BaseTest {
    
    let downloadLink = "https://speed.hetzner.de/10GB.bin" //to be replaced with mock server link from https://linear.app/beamapp/issue/BE-3873/add-a-feature-httpmockserver-to-generate-a-file
    let omniBoxView = OmniBoxTestView()
    var downloadsView: DownloadTestView?

    func testDownloadView() throws {
        let journalView = launchApp()
        
        step("Given I start downloading process using \(downloadLink) link"){
            journalView.searchInOmniBox(downloadLink, true)
            downloadsView = omniBoxView.openDownloadsView()
        }
        
        step("Then downloads view shows corerctlabels and buttons"){
            if !downloadsView!.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout) {
                journalView.searchInOmniBox(downloadLink, true)
                omniBoxView.openDownloadsView()
            }
            XCTAssertTrue(downloadsView!.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView!.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView!.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView!.button(DownloadViewLocators.Buttons.viewInFinderButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(downloadsView!.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).exists)
        }

        step("When I stop downloading process"){
            downloadsView!.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        }
        
        step("Then resume download button exists and stop download button doesn't exist"){
            XCTAssertTrue(downloadsView!.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(downloadsView!.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        }
    }
    
    func testClearDownload() throws {
        let journalView = launchApp()
        
        step("Given I start downloading process using \(downloadLink) link"){
            journalView.searchInOmniBox(downloadLink, true)
            downloadsView = omniBoxView.openDownloadsView()
        }
        
        step("When I stop downloading process"){
            if !downloadsView!.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout) {
                journalView.searchInOmniBox(downloadLink, true)
                omniBoxView.openDownloadsView()
            }
            downloadsView!.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        }

        step("Then I can see Clear button available"){
            XCTAssertTrue(downloadsView!.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step("When I click Clear button"){
            downloadsView!.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).click()
        }
        
        step("Then Downloads option is unavailable anymore"){
            waitFor(PredicateFormat.notExists.rawValue, omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier))
            XCTAssertFalse(downloadsView!.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
            XCTAssertFalse(omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
        }

    }
}
