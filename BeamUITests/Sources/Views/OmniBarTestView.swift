//
//  OmniBarView.swift
//  BeamUITests
//
//  Created by Andrii on 28.07.2021.
//

import Foundation

class OmniBarTestView: BaseView {
    
    func clickRefreshButton() {
        button(OmniBarLocators.Buttons.refreshButton.accessibilityIdentifier).click()
    }
    
    func clickBackButton() {
        button(OmniBarLocators.Buttons.backButton.accessibilityIdentifier).click()
    }
    
    func clickForwardButton() {
        button(OmniBarLocators.Buttons.forwardButton.accessibilityIdentifier).click()
    }
    
    func navigateToJournalViaHomeButton() {
        button(OmniBarLocators.Buttons.homeButton.accessibilityIdentifier).click()
    }
    
    func navigateToJournalViaPivotButton() {
        button(OmniBarLocators.Buttons.openCardButton.accessibilityIdentifier).click()
    }
    
    func navigateToWebView() {
        button(OmniBarLocators.Buttons.openWebButton.accessibilityIdentifier).click()
    }
    
    @discardableResult
    func openDownloadsView() -> DownloadTestView {
        _ = button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        button(OmniBarLocators.Buttons.downloadsButton.accessibilityIdentifier).click()
        return DownloadTestView()
    }
}
