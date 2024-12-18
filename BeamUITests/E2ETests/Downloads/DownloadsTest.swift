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
    var journalView = JournalTestView()
    var downloadsView = DownloadTestView()

    override func setUp() {
        super.setUp()
        
        step("Given I start downloading process using \(downloadLink) link"){
            journalView.searchInOmniBox(downloadLink, true)
        }
        
        step("When I open download pop up"){
            omniBoxView.openDownloadsView()
        }
        
    }
    
    func testDownloadView() throws {

        step("Then downloads view shows correct labels and buttons"){
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.viewInFinderButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).exists)
        }

        step("When I stop downloading process"){
            downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).clickOnExistence()
        }
        
        step("Then resume download button exists and stop download button doesn't exist"){
            XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        }
    }
    
    func testClearDownload() throws {
        
        step("When I stop downloading process"){
            downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).clickOnExistence()
        }

        step("Then I can see Clear button available"){
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step("When I click Clear button"){
            downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).clickOnExistence()
        }
        
        step("Then Downloads option is unavailable anymore"){
            waitFor(PredicateFormat.notExists.rawValue, omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier))
            XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
            XCTAssertFalse(omniBoxView.button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
        }

    }
    
    func testPopOverOpenMultipleTimes() throws { //BE-4499

        step("Then download pop up is opened"){
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step("When I close download pop up"){
            omniBoxView.openDownloadsView()
        }
        
        step("Then download pop up is closed"){
            XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I open download pop up"){
            omniBoxView.openDownloadsView()
        }

        step("Then download pop up is opened"){
            XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
    }
}
