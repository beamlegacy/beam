//
//  JavascriptNativeAlertsTests.swift
//  BeamUITests
//
//  Created by Andrii on 09.08.2021.
//

import Foundation
import XCTest

class JavascriptNativeInteractionsTests: BaseTest {
    
    
    @discardableResult
    func prepareTest(_ buttonTitle: String) -> (XCUIElement, XCUIElement, XCUIElement) {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        
        testRailPrint("Given I open a test page to \(buttonTitle)")
        helper.openTestPage(page: .alerts)
        
        let webViewElement = journalView.app.webViews.containing(.button, identifier: buttonTitle).element
        let button = webViewElement.buttons[buttonTitle].firstMatch
        button.clickOnHittable()
        testRailPrint("When \(buttonTitle) is invoked")
        let alert = journalView.app.dialogs.firstMatch
        XCTAssert(alert.waitForExistence(timeout: minimumWaitTimeout))
        return (webViewElement, alert, button)
    }
    
    func testJSNativeAlertInteraction() {
        let preparationResult = prepareTest("Trigger an alert")
        let alert = preparationResult.1
        
        testRailPrint("Then alert box is displayed and interacted")
        XCTAssert(alert.waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertTrue(alert.staticTexts["Hello! I am an alert box!"].waitForExistence(timeout: minimumWaitTimeout))
        alert.buttons["Ok"].firstMatch.tap()
    }
    
    func testJSNativePromptInteraction() {
        let preparationResult = prepareTest("Trigger a prompt")
        let webView = preparationResult.0
        let alert = preparationResult.1
        
        testRailPrint("Then prompt is interactable")
        let textField = alert.textFields.firstMatch
        textField.tap()
        textField.typeText("Scotty")

        alert.buttons["Submit"].firstMatch.tap()
        XCTAssertTrue(webView.staticTexts["Beam me up, Scotty!"].waitForExistence(timeout: minimumWaitTimeout))
    }
    
    func testJSNativeConfirmationInteraction() {
        let preparationResult = prepareTest("Trigger a confirm")
        let webView = preparationResult.0
        let alert = preparationResult.1
        let button = preparationResult.2
        
        testRailPrint("Then confirmation pop-up is interactable for cancelation and confirmation")
        let ok = alert.buttons["OK"].firstMatch
        let cancel = alert.buttons["Cancel"].firstMatch
        
        ok.tap()
        XCTAssertTrue(webView.staticTexts["YES"].waitForExistence(timeout: minimumWaitTimeout))
        
        button.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: minimumWaitTimeout))
        
        cancel.tap()
        XCTAssertTrue(webView.staticTexts["NO"].waitForExistence(timeout: minimumWaitTimeout))
    }
    
    func testJSNativeFileDialogInteraction() {
        let fileExistanceLabel = "NO FILE"
        let journalView = launchApp()
        
        testRailPrint("Given I open a test page with Upload File dialog")
        BeamUITestsHelper(journalView.app).openTestPage(page: .alerts)
        let message = "no file selected"
        let webView = journalView.app.webViews.containing(.button, identifier: message).element
        XCTAssert(webView.waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertTrue(webView.staticTexts[fileExistanceLabel].waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("When \(message) is clicked")
        webView.buttons[message].tap()

        testRailPrint("Then I can successfully upload the file")
        let alert = journalView.app.dialogs.firstMatch
        XCTAssert(alert.waitForExistence(timeout: minimumWaitTimeout))
        let open = alert.buttons["Open"].firstMatch

        journalView.app.typeKey("g", modifierFlags: [.command, .shift])

        let sheet = alert.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: minimumWaitTimeout))

        let goButton = alert.buttons["Go"]
        let input = sheet.comboBoxes.firstMatch
        input.typeText("/Applications")
        goButton.tap()
        WaitHelper().waitForDoesntExist(goButton)
        journalView.typeKeyboardKey(.downArrow)
        open.clickOnEnabled()
        XCTAssertTrue(WaitHelper().waitForDoesntExist(webView.staticTexts[fileExistanceLabel]))
    }
    
}
