//
//  CookieBannerBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 03/06/2022.
//

import Foundation
import XCTest

class CookieBannerBlockerTests: BaseTest {
    
    let privacyWindow = PrivacyPreferencesTestView()
    let url = MockHTTPWebPages().getMockPageUrl(.cookieBannerAdBlock)
    let cookieBannerElements = [
        "THIS WEBSITE USES COOKIES",
        "We use cookies to personalise content and ads, to provide social media features and to analyse our traffic.",
        "OK ",
        "Decline"
    ]

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .privacy)
    }
    
    private func verifyCookieBannerDisplayed(_ status: Bool){
        for cookieBannerElement in cookieBannerElements {
            XCTAssertEqual(app.windows["AdBlock"].webViews["AdBlock"].staticTexts[cookieBannerElement].exists, status)
        }
    }
    
    func testEnabledCookieBannerBlocker(){
        testrailId("C646")
        step ("Given Hide Cookie Banner blocker setting is enabled"){
            if !privacyWindow.getCookieBannerBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickCookieBannerBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.getCookieBannerBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.cookieBannerAdBlock)
        }
        
        step ("Then cookie banner is enabled displayed"){
            verifyCookieBannerDisplayed(false)
        }
    }
    
    func testDisabledCookieBannerBlocker(){
        testrailId("C646")
        step ("Given Hide Cookie Banner button blocker setting is disabled"){
            if privacyWindow.getCookieBannerBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickCookieBannerBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.getCookieBannerBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.cookieBannerAdBlock)
        }
        
        step ("Then cookie banner is displayed"){
            verifyCookieBannerDisplayed(true)
        }
    }
    
}
