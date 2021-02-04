//
//  Omnibar.swift
//  BeamUITests
//
//  Created by Ravichandrane Rajendran on 03/02/2021.
//

import XCTest

class Omnibar: XCTestCase {

    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }

    func testOmnibarIsFocus() {
        let textField = app.textFields["omniBarSearchBox"]
        let hasKeyboardFocus = textField.value(forKey: "hasKeyboardFocus") as? Bool ?? false

        XCTAssert(textField.exists)
        XCTAssertTrue(hasKeyboardFocus)
    }

    func testOmnibarCanSearch() {
        let textField = app.textFields["omniBarSearchBox"]

        XCTAssert(textField.exists)

        textField.typeText("Hello World")

        guard let text = textField.value as? String else {
            XCTFail("Search Query: Textfield has no string value")
            return
        }

        XCTAssertEqual(text, "Hello World")
    }

    func testOmnibarClearSearchQuery() {
        let textField = app.textFields["omniBarSearchBox"]
        let selectAll = XCUIApplication().menuItems["Select All"]

        XCTAssert(textField.exists)

        textField.typeText("Hello World")

        guard let text = textField.value as? String else {
            XCTFail("ClearSearchQuery #1 : Textfield has no string value")
            return
        }

        XCTAssertEqual(text, "Hello World")

        selectAll.tap()
        textField.typeText(XCUIKeyboardKey.delete.rawValue)

        guard let emptyText = textField.value as? String else {
            XCTFail("ClearSearchQuery #2: Textfield has no string value")
            return
        }

        XCTAssertEqual(emptyText, "")
    }

    func testDeleteCharactersInOmnibar() {
        let textField = app.textFields["omniBarSearchBox"]

        XCTAssert(textField.exists)

        textField.typeText("Hello World")
        textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))

        guard let text = textField.value as? String else {
            XCTFail("DeleteCharacters : Textfield has no string value")
            return
        }

        XCTAssertEqual(text, "Hello Wor")
    }

    func testOmnibarShowAutoComplete() {
        let textField = app.textFields["omniBarSearchBox"]

        XCTAssert(textField.exists)

        textField.typeText("Hello World")

        let autocomplete = app.scrollViews["autoCompleteView"]

        XCTAssert(autocomplete.exists)
    }

    func testOmnibarCanNavigateThroughTheAutoComplete() {
        let textField = app.textFields["omniBarSearchBox"]

        XCTAssert(textField.exists)
        textField.typeText("beam app")

        let autocomplete = app.scrollViews["autoCompleteView"]

        XCTAssert(autocomplete.exists)

        textField.typeKey(.downArrow, modifierFlags: .function)

        XCTAssert(app.staticTexts["selected"].exists)
    }

    func testOmnibarCanPressEnterAndSwitchMode() {
        let textField = app.textFields["omniBarSearchBox"]

        XCTAssert(textField.exists)
        textField.typeText("Hello World")

        let autocomplete = app.scrollViews["autoCompleteView"]

        XCTAssert(autocomplete.exists)

        textField.typeKey(.downArrow, modifierFlags: .function)
        textField.typeKey(.downArrow, modifierFlags: .function)
        textField.typeKey(.downArrow, modifierFlags: .function)
        textField.typeKey(.downArrow, modifierFlags: .function)

        textField.typeText("\r")

        XCTAssert(app.images["browserTabBarView"].waitForExistence(timeout: 2))
        XCTAssert(app.groups["webView"].exists)

        testOmnibarCommonRightButtonsExist()
        XCTAssert(app.buttons["note"].exists)

        app.buttons["note"].click()
        XCTAssert(app.scrollViews["noteView"].exists)

        app.buttons["network"].click()
        XCTAssert(app.groups["webView"].exists)
    }

    func testOmnibarBackAndForwardButtonsExist() {
        XCTAssert(app.buttons["goBack"].exists)
        XCTAssert(app.buttons["goForward"].exists)
    }

    func testOmnibarRightNetworkButtonExist() {
        testOmnibarCommonRightButtonsExist()
        XCTAssert(app.buttons["network"].exists)
    }

    func testOmnibarCommonRightButtonsExist() {
        XCTAssert(app.buttons["magnifyingglass"].exists)
        XCTAssert(app.buttons["newSearch"].exists)
    }
}
