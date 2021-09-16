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
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.alerts)
        
        let webViewElement = journalView.app.webViews.containing(.button, identifier: buttonTitle).element
        let button = webViewElement.buttons[buttonTitle].firstMatch
        button.tap()
        testRailPrint("When \(buttonTitle) is invoked")
        let alert = journalView.app.dialogs.firstMatch
        XCTAssert(alert.waitForExistence(timeout: implicitWaitTimeout))
        return (webViewElement, alert, button)
    }
    
    func testJSNativeAlertInteraction() {
        let preparationResult = prepareTest("Trigger an alert")
        let alert = preparationResult.1
        
        testRailPrint("Then alert box is displayed and interacted")
        XCTAssert(alert.waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(alert.staticTexts["Hello! I am an alert box!"].exists)
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
        XCTAssertTrue(webView.staticTexts["Beam me up, Scotty!"].exists)
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
        XCTAssertTrue(webView.staticTexts["YES"].exists)
        
        button.tap()
        XCTAssert(alert.waitForExistence(timeout: implicitWaitTimeout))
        
        cancel.tap()
        XCTAssertTrue(webView.staticTexts["NO"].exists)
    }
    
    func testJSNativeFileDialogInteraction() {
        let fileExistanceLabel = "NO FILE"
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        
        testRailPrint("Given I open a test page with Upload File dialog")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.alerts)
        let message = "no file selected"
        let webView = journalView.app.webViews.containing(.button, identifier: message).element
        XCTAssert(webView.exists)
        XCTAssertTrue(webView.staticTexts[fileExistanceLabel].exists)
        
        testRailPrint("When \(message) is clicked")
        webView.buttons[message].tap()

        testRailPrint("Then I can successfully upload the file")
        let alert = journalView.app.dialogs.firstMatch
        XCTAssert(alert.waitForExistence(timeout: implicitWaitTimeout))
        let ok = alert.buttons["Open"].firstMatch

        journalView.app.typeKey("g", modifierFlags: [.command, .shift])

        let sheet = alert.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: implicitWaitTimeout))

        let goButton = alert.buttons["Go"]
        let input = sheet.comboBoxes.firstMatch
        input.typeText("/Applications")
        goButton.tap()
        sleep(2)
        journalView.typeKeyboardKey(.downArrow)
        ok.tap()
        XCTAssertFalse(webView.staticTexts[fileExistanceLabel].exists)
    }
    
}
