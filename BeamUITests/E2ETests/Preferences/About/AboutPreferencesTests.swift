//
//  ReportBugFeatureTests.swift
//  BeamUITests
//
//  Created by Andrii on 07/04/2022.
//

import Foundation
import XCTest

class AboutPreferencesTests: BaseTest {
    
    var aboutPreferencesView: AboutPreferencesTestView!
    var tabIndex = 0
    let expectedBugsTabTitle = "beamapp.canny.io/bugs"
    let expectedFeatureTabTitle = "beamapp.canny.io/feature-r"
    let expectedTwitterTabTitle = "twitter.com/getonbeam"
    let expectedTermsOfServicesTabTitle = "public.beamapp.co/beam/note/e2a2291f-37d5-443b-aa88-af6b04520fee/Terms-of-Services"
    let expectedPrivacyPolicyTabTitle = "public.beamapp.co/beam/note/1085ef50-2df0-4ac6-b8af-9c0b10d82b34/Privacy-Policy"
    
    @discardableResult
    private func openAboutPreferences() -> AboutPreferencesTestView {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .about)
        return AboutPreferencesTestView()
    }
    
    private func assertCorrectTabIsOpened(_ expectedUrl: String) {
        step ("THEN I see \(expectedUrl) URL opened") {
            let tabToAssert = tabIndex
            tabIndex += 1
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), tabIndex)
            let tabURL = webView.getTabUrlAtIndex(index: tabToAssert)
            XCTAssertTrue(tabURL.hasPrefix(expectedUrl), "Actual web url is \(tabURL)")
        }
    }
    
    override func setUp() {
        step ("GIVEN I open About preferences") {
            launchApp()
            aboutPreferencesView = self.openAboutPreferences()
        }
    }
    
    func testExternalWebSourcesOpeningViaButtons() {
        testrailId("C613")
        step ("WHEN I click Report Feature button") {
            aboutPreferencesView.clickFeatureRequestButton()
        }
        assertCorrectTabIsOpened(expectedFeatureTabTitle)
        
        testrailId("C614")
        step ("WHEN I click Report Bug button") {
            aboutPreferencesView.clickReportBugButton()
        }
        assertCorrectTabIsOpened(expectedBugsTabTitle)
        
        testrailId("C615")
        step ("WHEN I click Follow button") {
            aboutPreferencesView.clickFollowTwitterButton()
        }
        assertCorrectTabIsOpened(expectedTwitterTabTitle)
    }
    
    func testTermsOfServiceHyperlink() {
        testrailId("C611")
        step ("WHEN I click Terms of service hyperlink") {
            aboutPreferencesView.clickTermsOfServiceHyperlink()
        }
        assertCorrectTabIsOpened(expectedTermsOfServicesTabTitle)
    }
    
    func testPrivacyPolicyHyperlink() {
        testrailId("C612")
        step ("WHEN I click Privacy policy hyperlink") {
            aboutPreferencesView.clickPrivacyPolicyHyperlink()
        }
        assertCorrectTabIsOpened(expectedPrivacyPolicyTabTitle)
    }
    
}
