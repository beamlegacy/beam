//
//  ReportBugFeatureTests.swift
//  BeamUITests
//
//  Created by Andrii on 07/04/2022.
//

import Foundation
import XCTest

class ReportBugFeatureTests: BaseTest {
    
    var aboutPreferencesView: AboutPreferencesTestView?
    
    @discardableResult
    private func openAboutPreferences() -> AboutPreferencesTestView {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .about)
        return AboutPreferencesTestView()
    }
    
    func testBugFeatureWebPagesOpening() {
        
        let expectedBugsUrl = "https://beamapp.canny.io/bugs"
        let expectedFeaturesUrl = "https://beamapp.canny.io/feature-r"
        
        step ("GIVEN I open About preferences") {
            launchApp()
            aboutPreferencesView = self.openAboutPreferences()
        }
        
        step ("WHEN I click Report Feature button") {
            aboutPreferencesView?.clickFeatureRequestButton()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step ("THEN I see \(expectedFeaturesUrl) URL opened") {
            XCTAssertTrue(webView
                            .activateSearchFieldFromTab(index: 0)
                            .waitForSearchFieldValueToEqual(expectedValue: expectedFeaturesUrl))
        }
        
        step ("WHEN I click Report Bug button") {
            self.openAboutPreferences()
            aboutPreferencesView?.clickReportBugButton()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step ("THEN I see \(expectedBugsUrl) URL opened") {
            XCTAssertTrue(webView
                            .activateSearchFieldFromTab(index: 1)
                            .waitForSearchFieldValueToEqual(expectedValue: expectedBugsUrl))
        }
        
    }
    
}
