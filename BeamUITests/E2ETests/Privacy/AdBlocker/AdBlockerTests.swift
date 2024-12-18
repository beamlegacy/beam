//
//  AdBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation
import XCTest

class AdBlockerTests: BaseTest {
    
    let adBlockerPage = AdBlockerTestView()
    let url = MockHTTPWebPages().getMockPageUrl(.fullSiteAdBlock)
    let hostURL = "a-stat.test.adblock.lvh.me"
    let tabTitleOfTestPage = "AdBlock"
    let tabTitleOfAdBlocker = "Site is blocked by Beam"
    let privacyWindow = PrivacyPreferencesTestView()

    override func setUp() {
        super.setUp()
        uiMenu.invoke(.startMockHttpServer)
    }
    
    private func verifyWebsiteIsBlocked(index: Int, url: String, hostUrl: String) {
        step("Then \(url) is blocked") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), index + 1)
            XCTAssertTrue(adBlockerPage.isWebsiteBlocked())
            moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: index), tabTitleOfAdBlocker)
            XCTAssertEqual(adBlockerPage.getBlockedUrlElement().getStringValue(), "The site “\(url)”")
            XCTAssertEqual(adBlockerPage.getBlockedHostElement().getStringValue(), "Disable blocking for \(hostUrl)")
        }
    }
    
    private func verifyWebsiteIsNotBlocked(index: Int) {
        step("Then \(url) is not blocked") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), index + 1)
            XCTAssertFalse(adBlockerPage.isWebsiteBlocked())
            moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: index), tabTitleOfTestPage)
        }
    }
    
    func testBlockedWebsiteAllowOnce() {
        step("Given I navigate to blocked test page \(url)") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 0, url: url, hostUrl: hostURL)
        
        step("When I allow the website \(url) once") {
            webView = adBlockerPage.allowWebSiteOnce()
        }
        
        step("Then website \(url) is displayed") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), tabTitleOfTestPage)
        }
        
        testrailId("C504")
        step("When I relaunch \(url) in the same tab") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
        
        step("When I relaunch \(url) in another tab") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            webView = mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 1, url: url, hostUrl: hostURL)
        
        step("When I allow the website \(url) once") {
            webView = adBlockerPage.allowWebSiteOnce()
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 1), tabTitleOfTestPage)
        }
        
        step("And I reload the tab") {
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        }
        
        verifyWebsiteIsBlocked(index: 1, url: url, hostUrl: hostURL)
        
    }
    
    func testBlockedWebsitePermanentlyAllowed() {
        
        step("Given I navigate to blocked test page \(url)") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 0, url: url, hostUrl: hostURL)
        
        step("When I access to Allow List in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
            privacyWindow.accessAllowList()
        }
        
        step("Then Allow list is empty") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
            privacyWindow.cancelAllowList()
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step("When I allow the website permanently") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            webView = adBlockerPage.allowWebSitePermanently()
        }
        
        step("Then website \(url) is displayed") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), tabTitleOfTestPage)
        }
        
        step("When I relaunch \(url) in the same tab") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
        
        step("When I relaunch \(url) in another tab") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            webView = mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 1)
        
        step("When I reload the tab") {
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        }
        
        verifyWebsiteIsNotBlocked(index: 1)
        
        step("When I access to Allow List in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
            PrivacyPreferencesTestView().accessAllowList()
        }
        
        step("Then host \(hostURL) is correctly added") {
            XCTAssertEqual(privacyWindow.getAllowListUrlByIndex(0).getStringValue(), hostURL)
        }
    }
    
    func testAddManuallyAllowUrl() {
        testrailId("C650")
        step("Given I access to Allow List in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
            privacyWindow.accessAllowList()
        }
        
        step("Then Allow list is empty") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
        
        step("When I add \(hostURL) in Allow List") {
            privacyWindow.addAllowUrl().fillNewUrl(hostURL).saveAllowList()
            shortcutHelper.shortcutActionInvoke(action: .closeTab) // close
        }
        
        step("And I navigate to blocked test page \(url)") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            mockPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
    }
}
