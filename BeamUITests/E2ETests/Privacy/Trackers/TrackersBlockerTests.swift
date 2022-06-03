//
//  TrackersBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 03/06/2022.
//

import Foundation
import XCTest

class TrackersBlockerTests: BaseTest {
    
    let mockHttpPage = MockHTTPWebPages()
    let uiMenu = UITestsMenuBar()
    let shortcutHelper = ShortcutsHelper()
    let privacyWindow = PrivacyPreferencesTestView()
    let url = MockHTTPWebPages().getMockPageUrl(.socialMediaAdBlock)
    let socialMediaButtons = [
        "Partager sur Facebook",
        "Envoyer par e-mail",
        "Partager sur Messenger",
        "Twitter",
        "Linkedin",
        "Copier le lien"
    ]
    let socialMediaLinks = [
        "Partager sur Whatsapp",
        "Partage"
    ]
    
    var app = XCUIApplication().windows["AdBlock"]

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .privacy)
    }
    
    private func isSocialMediaButtonDisplayed(_ button: String) -> Bool {
        return app.buttons[button].exists
    }
    
    private func isSocialMediaLinkDisplayed(_ button: String) -> Bool {
        return app.staticTexts[button].exists
    }
    
    private func verifySocialMediaButtonsDisplayed(_ status: Bool){
        for socialMediaButton in socialMediaButtons {
            XCTAssertEqual(isSocialMediaButtonDisplayed(socialMediaButton), status)
        }
        for socialMediaLink in socialMediaLinks {
            XCTAssertEqual(isSocialMediaLinkDisplayed(socialMediaLink), status)
        }
    }
    
    func testEnabledTrackersBlocker(){
        
        step ("Given social media button blocker setting is disabled"){
            if (!privacyWindow.isSettingEnabled(element: privacyWindow.getSocialMediaButtonBlockerSettingElement())) {
                privacyWindow.clickInsideSocialMediaButtonBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.isSettingEnabled(element: privacyWindow.getSocialMediaButtonBlockerSettingElement()))
        }
        
        step ("When I navigate to \(url)"){
            mockHttpPage.openMockPage(.socialMediaAdBlock)
        }
        
        step ("Then social media buttons are not displayed"){
            verifySocialMediaButtonsDisplayed(false)
        }
    }
    
    func testDisabledTrackersBlocker(){
        
        step ("Given social media button blocker setting is disabled"){
            if (privacyWindow.isSettingEnabled(element: privacyWindow.getSocialMediaButtonBlockerSettingElement())) {
                privacyWindow.clickInsideSocialMediaButtonBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.isSettingEnabled(element: privacyWindow.getSocialMediaButtonBlockerSettingElement()))
        }
        
        step ("When I navigate to \(url)"){
            mockHttpPage.openMockPage(.socialMediaAdBlock)
        }
        
        step ("Then social media buttons are displayed"){
            verifySocialMediaButtonsDisplayed(true)
        }
    }
}
