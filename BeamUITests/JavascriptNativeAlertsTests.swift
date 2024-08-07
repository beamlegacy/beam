//
//  JavascriptNativeAlertsTests.swift
//  BeamUITests
//
//  Created by Ludovic Ollagnier on 22/07/2021.
//

import Foundation
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif

class JavascriptNativeAlertsTests: QuickSpec {
    let app = XCUIApplication()
    var helper: BeamUITestsHelper!

    func manualBeforeTestSuite () {
        // QuickSpec beforeSuite is called before ALL
        // this is called only before all test of this test class.
        guard self.helper == nil else {
            return
        }
        self.app.launch()
        self.helper = BeamUITestsHelper(self.app)
        self.helper.openTestPage(page: .alerts)
    }

    override func spec() {

        describe("Displaying native panels from JS") {
            beforeEach {
                self.manualBeforeTestSuite()
                self.continueAfterFailure = false
            }

            it("Display alert") {
                let alertButtonTitle = "Trigger an alert"
                let webView = self.app.webViews.containing(.button, identifier: alertButtonTitle).element
                let button = webView.buttons[alertButtonTitle].firstMatch
                button.tap()

                let alert = self.app.dialogs.firstMatch
                XCTAssert(alert.waitForExistence(timeout: 4))
                XCTAssertTrue(alert.staticTexts["Hello! I am an alert box!"].exists)

                alert.buttons["Ok"].firstMatch.tap()
            }

            it("Display a prompt") {
                let alertButtonTitle = "Trigger a prompt"
                let webView = self.app.webViews.containing(.button, identifier: alertButtonTitle).element
                let button = webView.buttons[alertButtonTitle].firstMatch
                button.tap()

                let alert = self.app.dialogs.firstMatch
                XCTAssert(alert.waitForExistence(timeout: 4))

                let textField = alert.textFields.firstMatch
                textField.tap()
                textField.typeText("Scotty")

                alert.buttons["Submit"].firstMatch.tap()
                XCTAssertTrue(webView.staticTexts["Beam me up, Scotty!"].exists)
            }

            it("Display a confirm") {
                let alertButtonTitle = "Trigger a confirm"
                let webView = self.app.webViews.containing(.button, identifier: alertButtonTitle).element
                let button = webView.buttons[alertButtonTitle].firstMatch
                button.tap()

                let alert = self.app.dialogs.firstMatch
                XCTAssert(alert.waitForExistence(timeout: 4))

                let ok = alert.buttons["OK"].firstMatch
                XCTAssertTrue(ok.exists)
                let cancel = alert.buttons["Cancel"].firstMatch
                XCTAssertTrue(cancel.exists)
                ok.tap()
                XCTAssertTrue(webView.staticTexts["YES"].exists)
                button.tap()
                XCTAssert(alert.waitForExistence(timeout: 4))
                cancel.tap()
                XCTAssertTrue(webView.staticTexts["NO"].exists)
            }

            it("Display a file dialog") { [self] in
                let message = "no file selected"
                let webView = self.app.webViews.containing(.button, identifier: message).element
                XCTAssert(webView.exists)

                let noFileText = webView.staticTexts["NO FILE"].firstMatch

                XCTAssertTrue(noFileText.exists)

                webView.buttons["no file selected"].tap()

                let alert = self.app.dialogs.firstMatch
                XCTAssert(alert.waitForExistence(timeout: 4))
                let ok = alert.buttons["Open"].firstMatch
                XCTAssert(ok.exists)
                let cancel = alert.buttons["Cancel"].firstMatch
                XCTAssert(cancel.exists)

                self.app.typeKey("g", modifierFlags: [.command, .shift])

                let sheet = alert.sheets.firstMatch
                XCTAssert(sheet.waitForExistence(timeout: 5))

                let goButton = alert.buttons["Go"]
                let input = sheet.comboBoxes.firstMatch
                XCTAssert(goButton.exists)
                XCTAssert(input.exists)
                input.typeText("/Applications")
                goButton.tap()
                sleep(2)
                app.typeKey(.downArrow, modifierFlags: [])
                ok.tap()

                noFileText.waitForNonExistence(timeout: 5, for: self)
                XCTAssertFalse(noFileText.exists)
            }
        }
    }
}
