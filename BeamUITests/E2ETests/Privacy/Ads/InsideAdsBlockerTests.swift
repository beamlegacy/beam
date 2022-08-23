//
//  InsideAdsBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 31/05/2022.
//

import Foundation
import XCTest

class InsideAdsBlockerTests: BaseTest {
    
    let privacyWindow = PrivacyPreferencesTestView()
    let url = MockHTTPWebPages().getMockPageUrl(.insideAdBlock)
    let adLinkText = "Featured Deals made easy all year long. Free shipping. Best prices. Get your thing Get your thing"
    let view = "AdBlock"

    override func setUpWithError() throws {
        step ("GIVEN I start mock server and navigate to privacy prefs"){
            launchApp()
            uiMenu.destroyDB()
                .startMockHTTPServer()
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .privacy)
        }
    }
    
    func testDisabledInsideAdsBlocker(){
        testrailId("C642")
        step ("Given ads blocking setting is disabled"){
            if privacyWindow.getInsideAdBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickInsideAdBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.getInsideAdBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.insideAdBlock)
        }
        
        step ("Then inside ad is displayed"){
            XCTAssertTrue(app.windows[view].webViews[view].links[adLinkText].children(matching: .group).element(boundBy: 0).exists)
        }
    }
    
    func testEnabledInsideAdsBlocker(){
        testrailId("C642")
        step ("Given ads blocking setting is enabled"){
            if !privacyWindow.getInsideAdBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickInsideAdBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.getInsideAdBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.insideAdBlock)
        }
        
        step ("Then inside ad is not displayed"){
            XCTAssertFalse(app.windows[view].webViews[view].links[adLinkText].children(matching: .group).element(boundBy: 0).exists)
        }
    }
}
