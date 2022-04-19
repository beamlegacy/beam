//
//  MockHTTPWebPages.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class MockHTTPWebPages: BaseView {
    
    func getPasswordFieldElement(_ isSignUp: Bool = true) -> XCUIElement {
        let viewAccessibility = isSignUp ? "Sign Up" : "Sign In"
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:"Password: ").children(matching: .secureTextField).element
    }
    
    func getPasswordFieldElement(title: String) -> XCUIElement {
        return app.windows.webViews["Sign In"].groups.containing(.staticText, identifier:title).children(matching: .secureTextField).element
    }

    func getConfirmPasswordFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign Up"].groups.containing(.staticText, identifier:"Confirm Password: ").children(matching: .secureTextField).element
    }
    
    func getEmailFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign In"].groups.containing(.staticText, identifier:"Username: ").children(matching: .textField).element
    }

    func getUsernameFieldElement(title: String) -> XCUIElement {
        return app.windows.webViews["Sign In"].groups.containing(.staticText, identifier:title).children(matching: .textField).element
    }

    func getLinkElement(_ title: String) -> XCUIElement {
        return app.windows.webViews["Sign In"].links.containing(.staticText, identifier: title).element
    }

    func getContinueButtonElement() -> XCUIElement {
        return app.windows.webViews["Sign In"].buttons["Continue"]
    }

    func getResultValue(label: String) -> String? {
        let staticTexts = app.windows.webViews["Mock Form Server"].groups.containing(.staticText, identifier: label).children(matching: .staticText)
        guard staticTexts.count > 2 else { return nil }
        let element = staticTexts.element(boundBy: 2)
        return getElementStringValue(element: element)
    }
}
