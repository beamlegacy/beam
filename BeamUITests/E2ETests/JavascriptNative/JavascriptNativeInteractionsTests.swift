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
        
        step("Given I open a test page to \(buttonTitle)"){
            uiMenu.invoke(.loadUITestPageAlerts)
        }
        
        let webViewElement = journalView.app.webViews.containing(.button, identifier: buttonTitle).element
        let button = webViewElement.buttons[buttonTitle].firstMatch
        let alert = journalView.app.dialogs.firstMatch

        step("When \(buttonTitle) is invoked"){
            button.clickOnHittable()
            XCTAssert(alert.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        return (webViewElement, alert, button)

    }
    
    func testJSNativeAlertInteraction() {
        let preparationResult = prepareTest("Trigger an alert")
        let alert = preparationResult.1
        
        step("Then alert box is displayed and interacted"){
            XCTAssert(alert.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(alert.staticTexts["Hello! I am an alert box!"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            alert.buttons["OK"].firstMatch.tap()
        }

    }
    
    func testJSNativePromptInteraction() {
        let preparationResult = prepareTest("Trigger a prompt")
        let webView = preparationResult.0
        let alert = preparationResult.1
        
        step("Then prompt is interactable"){
            let textField = alert.textFields.firstMatch
            textField.tap()
            textField.typeText("Scotty")

            alert.buttons["Submit"].firstMatch.tap()
            XCTAssertTrue(webView.staticTexts["Beam me up, Scotty!"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

    }
    
    func testJSNativeConfirmationInteraction() {
        let preparationResult = prepareTest("Trigger a confirm")
        let webView = preparationResult.0
        let alert = preparationResult.1
        let button = preparationResult.2
        
        step("Then confirmation pop-up is interactable for cancelation and confirmation"){
            let ok = alert.buttons["OK"].firstMatch
            let cancel = alert.buttons["Cancel"].firstMatch
            
            ok.tap()
            XCTAssertTrue(webView.staticTexts["YES"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            
            button.tap()
            XCTAssertTrue(alert.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            
            cancel.tap()
            XCTAssertTrue(webView.staticTexts["NO"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

    }
    
    func testJSNativeFileDialogInteraction() {
        let fileExistanceLabel = "NO FILE"
        let message = "no file selected"
        let journalView = launchApp()
        var webView: XCUIElement?
        
        step("Given I open a test page with Upload File dialog"){
            uiMenu.invoke(.loadUITestPageAlerts)
            webView = journalView.app.webViews.containing(.button, identifier: message).element
            XCTAssert(webView!.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(webView!.staticTexts[fileExistanceLabel].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
 
        step("When \(message) is clicked"){
            webView!.buttons[message].tap()
        }

        step("Then I can successfully upload the file"){
            let alert = journalView.app.dialogs.firstMatch
            XCTAssert(alert.waitForExistence(timeout: BaseTest.minimumWaitTimeout))

            // Go to application folder
            journalView.app.typeKey("a", modifierFlags: [.command, .shift])
            // Group by none to avoid flaky issue
            journalView.app.typeKey("1", modifierFlags: [.command, .control])
            journalView.typeKeyboardKey(.downArrow)
            journalView.typeKeyboardKey(.enter)

            XCTAssertTrue(waitForDoesntExist(webView!.staticTexts[fileExistanceLabel]))
        }

    }
    
}
