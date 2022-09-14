//
//  TrackersBlockerTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 03/06/2022.
//

import Foundation
import XCTest

class TrackersBlockerTests: BaseTest {
    
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
    

    override func setUpWithError() throws {
        launchApp()
        uiMenu.invoke(.destroyDB)
            .invoke(.startMockHttpServer)
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .privacy)
    }
    
    private func isSocialMediaButtonDisplayed(_ button: String) -> Bool {
        return app.windows["AdBlock"].buttons[button].exists
    }
    
    private func isSocialMediaLinkDisplayed(_ button: String) -> Bool {
        return app.windows["AdBlock"].staticTexts[button].exists
    }
    
    private func verifySocialMediaButtonsDisplayed(_ status: Bool){
        for socialMediaButton in socialMediaButtons {
            XCTAssertEqual(isSocialMediaButtonDisplayed(socialMediaButton), status)
        }
        for socialMediaLink in socialMediaLinks {
            XCTAssertEqual(isSocialMediaLinkDisplayed(socialMediaLink), status)
        }
    }
    
    func testEnabledSocialMediaTrackersBlocker(){
        testrailId("C644")
        step ("Given social media button blocker setting is disabled"){
            if !privacyWindow.getSocialMediaButtonBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickInsideSocialMediaButtonBlockerSetting()
            }
            XCTAssertTrue(privacyWindow.getSocialMediaButtonBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.socialMediaAdBlock)
        }
        
        step ("Then social media buttons are not displayed"){
            verifySocialMediaButtonsDisplayed(false)
        }
    }
    
    func testDisabledSocialMediaTrackersBlocker(){
        testrailId("C644")
        step ("Given social media button blocker setting is disabled"){
            if privacyWindow.getSocialMediaButtonBlockerSettingElement().isSettingEnabled() {
                privacyWindow.clickInsideSocialMediaButtonBlockerSetting()
            }
            XCTAssertFalse(privacyWindow.getSocialMediaButtonBlockerSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .closeTab)
        }
        
        step ("When I navigate to \(url)"){
            mockPage.openMockPage(.socialMediaAdBlock)
        }
        
        step ("Then social media buttons are displayed"){
            verifySocialMediaButtonsDisplayed(true)
        }
    }
}
