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
    let app = XCUIApplication().windows["AdBlock"].webViews["AdBlock"]
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
            XCTAssertEqual(app.staticTexts[cookieBannerElement].exists, status)
        }
    }
    
    func testEnabledCookieBannerBlocker(){
        
        step ("Given Hide Cookie Banner blocker setting is enabled"){
            if (!privacyWindow.isSettingEnabled(element: privacyWindow.getCookieBannerBlockerSettingElement())) {
                privacyWindow.clickCookieBannerBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.isSettingEnabled(element: privacyWindow.getCookieBannerBlockerSettingElement()))
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
        
        step ("Given Hide Cookie Banner button blocker setting is disabled"){
            if (privacyWindow.isSettingEnabled(element: privacyWindow.getCookieBannerBlockerSettingElement())) {
                privacyWindow.clickCookieBannerBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.isSettingEnabled(element: privacyWindow.getCookieBannerBlockerSettingElement()))
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
