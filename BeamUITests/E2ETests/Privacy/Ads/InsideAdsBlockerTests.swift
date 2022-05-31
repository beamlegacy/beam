//
//  InsideAdsBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 31/05/2022.
//

import Foundation
import XCTest

class InsideAdsBlockerTests: BaseTest {
    
    let uiMenu = UITestsMenuBar()
    let adBlockerPage = AdBlockerTestView()
    let shortcutHelper = ShortcutsHelper()
    let omniboxView = OmniBoxTestView()
    let privacyWindow = PrivacyPreferencesTestView()
    let url = "http://inside-adblock.test.adblock.lvh.me:8080/"
    let adLinkText = "Featured Deals made easy all year long. Free shipping. Best prices. Get your thing Get your thing"
    let view = "AdBlock"

    var app = XCUIApplication()

    override func setUpWithError() throws {
        app = launchApp().app
        uiMenu.destroyDB()
            .startMockHTTPServer()
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .privacy)
    }
    
    func testDisabledInsideAdsBlocker(){
        
        step ("Given ads blocking setting is disabled"){
            if (privacyWindow.isSettingEnabled(element: privacyWindow.getInsideAdBlockerSettingElement())) {
                privacyWindow.clickInsideAdBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.isSettingEnabled(element: privacyWindow.getInsideAdBlockerSettingElement()))
        }
        
        step ("When I navigate to \(url)"){
            omniboxView.searchInOmniBox(url, true)
        }
        
        step ("Then inside ad is displayed"){
            XCTAssertTrue(app.windows[view].webViews[view].links[adLinkText].children(matching: .group).element(boundBy: 0).exists)
        }
    }
    
    func testEnabledInsideAdsBlocker(){
        
        step ("Given ads blocking setting is enabled"){
            if (!privacyWindow.isSettingEnabled(element: privacyWindow.getInsideAdBlockerSettingElement())) {
                privacyWindow.clickInsideAdBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.isSettingEnabled(element: privacyWindow.getInsideAdBlockerSettingElement()))
        }
        
        step ("When I navigate to \(url)"){
            omniboxView.searchInOmniBox(url, true)
        }
        
        step ("Then inside ad is not displayed"){
            XCTAssertFalse(app.windows[view].webViews[view].links[adLinkText].children(matching: .group).element(boundBy: 0).exists)
        }
    }
}
