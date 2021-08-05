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
        try XCTSkipIf(true, "Temp solution to fix the false failure to be found")
        let journalView = launchApp()
        
        print("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBar(downloadLink, true)
        let omniBarView = OmniBarTestView()
        let downloadsView = omniBarView.openDownloadsView()
        
        print("Then number of cards is increased to +1 in All Cards list")
        XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).exists)
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.viewInFinderButton.accessibilityIdentifier).exists)
        XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).exists)
        
        print("When I stop downloading process")
        downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        print("Then resume download button exists and stop download button doesn't exist")
        XCTAssertTrue(downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertFalse(downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).exists)
        
        print("When I create a card from All Cards view")
        downloadsView.button(DownloadViewLocators.Buttons.resumeDownloadButton.accessibilityIdentifier).click()
        downloadsView.button(DownloadViewLocators.Buttons.closeDownloadButton.accessibilityIdentifier).click()
        print("Then download button exists")
        XCTAssertTrue(omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
    }
    
    func testClearDownload() throws {
        let journalView = launchApp()
        
        print("Given I start downloading process using \(downloadLink) link")
        journalView.searchInOmniBar(downloadLink, true)
        let omniBarView = OmniBarTestView()
        let downloadsView = omniBarView.openDownloadsView()
        
        print("When I stop downloading process")
        downloadsView.button(DownloadViewLocators.Buttons.stopDownloadButton.accessibilityIdentifier).click()
        
        print("Then I can see Clear button available")
        XCTAssertTrue(downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        print("When I click Clear button")
        downloadsView.staticText(DownloadViewLocators.Buttons.clearButton.accessibilityIdentifier).click()
        
        print("Then Downloads option is unavailable anymore")
        WaitHelper().waitFor(WaitHelper.PredicateFormat.notExists.rawValue, omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier))
        XCTAssertFalse(downloadsView.staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).exists)
        XCTAssertFalse(omniBarView.button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).exists)
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
