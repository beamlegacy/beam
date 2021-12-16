//
//  WebsiteAuthTest.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class WebsiteAuthTest: BaseTest {
    
    let searchAppWebsite = "rails.beamapp.co"
    let correctLogin = "beam"
    let correctPass = "jiUJDLr>3Dxx"
    
    func testAuthPopUpView() {
        let journalView = launchApp()
        OmniBarUITestsHelper(journalView.app).tapCommand(.omnibarFillHistory)
        testRailPrint("Given I open \(searchAppWebsite) link")
        journalView.openWebsite(searchAppWebsite)
        
        let websiteAuthPopupTestView = WebsiteAuthPopupTestView()
        
        testRailPrint("Then I see Website Auth Popup with the following elements on it:")
        XCTAssertTrue(websiteAuthPopupTestView.staticText(WebsiteAuthPopupViewLocators.Labels.titleLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(websiteAuthPopupTestView.staticText(WebsiteAuthPopupViewLocators.Labels.descriptionLabel.accessibilityIdentifier).exists)
        XCTAssertTrue(websiteAuthPopupTestView.checkBox(WebsiteAuthPopupViewLocators.Checkboxes.savePasswordCheckbox.accessibilityIdentifier).exists)
        XCTAssertTrue(websiteAuthPopupTestView.staticText(WebsiteAuthPopupViewLocators.Buttons.connectButton.accessibilityIdentifier).exists)
        XCTAssertTrue(websiteAuthPopupTestView.staticText(WebsiteAuthPopupViewLocators.Buttons.cancelButton.accessibilityIdentifier).exists)
        XCTAssertTrue(websiteAuthPopupTestView.textField(WebsiteAuthPopupViewLocators.TextFields.loginField.accessibilityIdentifier).exists)
        XCTAssertTrue(websiteAuthPopupTestView.secureTextField(WebsiteAuthPopupViewLocators.TextFields.passwordField.accessibilityIdentifier).exists)
        
        testRailPrint("When I click Cancel button")
        let appWebsiteView = websiteAuthPopupTestView.cancelAuthentication()
        
        testRailPrint("Then I see access denied message")
        XCTAssertTrue(appWebsiteView.staticText(AppWebsiteViewLocators.Labels.accessDeniedLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testAuthenticateSuccessfully() {
        let journalView = launchApp()
        OmniBarUITestsHelper(journalView.app).tapCommand(.omnibarFillHistory)
        testRailPrint("Given I open \(searchAppWebsite) link")
        journalView.openWebsite(searchAppWebsite)
        let websiteAuthPopupTestView = WebsiteAuthPopupTestView()
        
        testRailPrint("When I populate auth pop-up with correct credentials")
        let appWebsiteView = websiteAuthPopupTestView.authenticate(correctLogin, correctPass)
        
        testRailPrint("Then I'm successfully redirected to the website and pop-up is closed")
        XCTAssertTrue(appWebsiteView.staticText("Beam Objects").waitForExistence(timeout: implicitWaitTimeout) || appWebsiteView.staticText("Beam is where ideas take shape").waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testAuthenticationFailure() throws {
        try XCTSkipIf(true, "Skipped due to unknown false failure on server side. To be fixed soon")
        let journalView = launchApp()
        OmniBarUITestsHelper(journalView.app).tapCommand(.omnibarFillHistory)
        testRailPrint("Given I open \(searchAppWebsite) link")
        journalView.openWebsite(searchAppWebsite)
        let websiteAuthPopupTestView = WebsiteAuthPopupTestView()
        
        testRailPrint("When I populate auth pop-up with correct credentials")
        let appWebsiteView = websiteAuthPopupTestView.authenticate("somelogin", "somepass")
        
        testRailPrint("Then I see access denied message")
        XCTAssertTrue(appWebsiteView.staticText(AppWebsiteViewLocators.Labels.accessDeniedLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
    
}
