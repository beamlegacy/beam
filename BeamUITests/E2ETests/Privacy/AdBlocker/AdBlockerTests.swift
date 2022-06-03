//
//  AdBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation
import XCTest

class AdBlockerTests: BaseTest {
    
    let mockHttpPage = MockHTTPWebPages()
    let uiMenu = UITestsMenuBar()
    let adBlockerPage = AdBlockerTestView()
    let shortcutHelper = ShortcutsHelper()
    var webTestView = WebTestView()
    let url = MockHTTPWebPages().getMockPageUrl(.fullSiteAdBlock)
    let hostUrl = "a-stat.test.adblock.lvh.me"
    let tabTitleOfTestPage = "AdBlock"
    let tabTitleOfAdBlocker = "Site is blocked by Beam"
    let privacyWindow = PrivacyPreferencesTestView()
    private var helper: BeamUITestsHelper!

    override func setUpWithError() throws {
        helper = BeamUITestsHelper(launchApp().app)
        uiMenu.destroyDB()
            .startMockHTTPServer()
    }
    
    private func verifyWebsiteIsBlocked(index: Int, url: String, hostUrl: String) {
        step("Then \(url) is blocked") {
            XCTAssertEqual(webTestView.getNumberOfTabs(), index + 1)
            XCTAssertTrue(adBlockerPage.isWebsiteBlocked())
            helper.moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webTestView.getBrowserTabTitleValueByIndex(index: index), tabTitleOfAdBlocker)
            XCTAssertEqual(webTestView.getElementStringValue(element: adBlockerPage.getBlockedUrlElement()), "The site “\(url)”")
            XCTAssertEqual(webTestView.getElementStringValue(element: adBlockerPage.getBlockedHostElement()), "Disable blocking for \(hostUrl)")
        }
    }
    
    private func verifyWebsiteIsNotBlocked(index: Int) {
        step("Then \(url) is not blocked") {
            XCTAssertEqual(webTestView.getNumberOfTabs(), index + 1)
            XCTAssertFalse(adBlockerPage.isWebsiteBlocked())
            helper.moveMouseOutOfTheWay() // move mouse to not be on tab title
            XCTAssertEqual(webTestView.getBrowserTabTitleValueByIndex(index: index), tabTitleOfTestPage)
        }
    }
    
    func testBlockedWebsiteAllowOnce() {
        step("Given I navigate to blocked test page \(url)") {
            mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 0, url: url, hostUrl: hostUrl)
        
        step("When I allow the website \(url) once") {
            webTestView = adBlockerPage.allowWebSiteOnce()
        }
        
        step("Then website \(url) is displayed") {
            XCTAssertEqual(webTestView.getNumberOfTabs(), 1)
            XCTAssertEqual(webTestView.getBrowserTabTitleValueByIndex(index: 0), tabTitleOfTestPage)
        }
        
        step("When I relaunch \(url) in the same tab") {
            mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
        
        step("When I relaunch \(url) in another tab") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            webTestView = mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 1, url: url, hostUrl: hostUrl)
        
        step("When I allow the website \(url) once") {
            webTestView = adBlockerPage.allowWebSiteOnce()
            XCTAssertEqual(webTestView.getNumberOfTabs(), 2)
            XCTAssertEqual(webTestView.getBrowserTabTitleValueByIndex(index: 1), tabTitleOfTestPage)
        }
        
        step("And I reload the tab") {
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        }
        
        verifyWebsiteIsBlocked(index: 1, url: url, hostUrl: hostUrl)
        
    }
    
    func testBlockedWebsitePermanentlyAllowed() {
        
        step("Given I navigate to blocked test page \(url)") {
            mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsBlocked(index: 0, url: url, hostUrl: hostUrl)
        
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
            webTestView = adBlockerPage.allowWebSitePermanently()
        }
        
        step("Then website \(url) is displayed") {
            XCTAssertEqual(webTestView.getNumberOfTabs(), 1)
            XCTAssertEqual(webTestView.getBrowserTabTitleValueByIndex(index: 0), tabTitleOfTestPage)
        }
        
        step("When I relaunch \(url) in the same tab") {
            mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
        
        step("When I relaunch \(url) in another tab") {
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            webTestView = mockHttpPage.openMockPage(.fullSiteAdBlock)
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
        
        step("Then host \(hostUrl) is correctly added") {
            XCTAssertEqual(privacyWindow.getElementStringValue(element: privacyWindow.getAllowListUrlByIndex(0)), hostUrl)
        }
    }
    
    func testAddManuallyAllowUrl() {
        step("Given I access to Allow List in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
            privacyWindow.accessAllowList()
        }
        
        step("Then Allow list is empty") {
            XCTAssertFalse(privacyWindow.isAllowListFilled())
        }
        
        step("When I add \(hostUrl) in Allow List") {
            privacyWindow.addAllowUrl().fillNewUrl(hostUrl).saveAllowList()
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step("And I navigate to blocked test page \(url)") {
            mockHttpPage.openMockPage(.fullSiteAdBlock)
        }
        
        verifyWebsiteIsNotBlocked(index: 0)
    }
}
