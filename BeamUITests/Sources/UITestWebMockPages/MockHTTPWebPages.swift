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
    
    func getConfirmPasswordFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign Up"].groups.containing(.staticText, identifier:"Confirm Password: ").children(matching: .secureTextField).element
    }
    
    func getEmailFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign In"].groups.containing(.staticText, identifier:"Username: ").children(matching: .textField).element
    }
    
}
