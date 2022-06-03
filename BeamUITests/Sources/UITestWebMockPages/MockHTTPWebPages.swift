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
    
    func getPasswordFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .secureTextField).element
    }
    
    func getPasswordElementWithValue(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .textField).element
    }

    func getConfirmPasswordFieldElement() -> XCUIElement {
        return app.windows.webViews["Sign Up"].groups.containing(.staticText, identifier:"Confirm Password: ").children(matching: .secureTextField).element
    }

    func getUsernameFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .textField).element
    }

    func getLinkElement(_ title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].links.containing(.staticText, identifier: title).element
    }

    func getContinueButtonElement(inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].buttons["Continue"]
    }
    
    func getNextButtonElement(inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].staticTexts["Next"]
    }

    func getDropdownFieldElement(title: String, inView viewAccessibility: String = "Sign In") -> XCUIElement {
        return app.windows.webViews[viewAccessibility].groups.containing(.staticText, identifier:title).children(matching: .popUpButton).element
    }
    
    func setDropdownFieldElement(value: String, inView viewAccessibility: String = "Sign In") -> Void {
        app.windows.menuItems[value].click()
    }
    
    func getResultValue(label: String) -> String? {
        let staticTexts = app.windows.webViews["Mock Form Server"].groups.containing(.staticText, identifier: label).children(matching: .staticText)
        guard staticTexts.count > 2 else { return nil }
        let element = staticTexts.element(boundBy: 2)
        return getElementStringValue(element: element)
    }
    
    enum MockPageLink: String, CaseIterable {
        case socialMediaAdBlock = "http://social-media-adblock.test.adblock.lvh.me:8080/"
        case insideAdBlock = "http://inside-adblock.test.adblock.lvh.me:8080/"
        case fullSiteAdBlock = "http://a-stat.test.adblock.lvh.me:8080/"
    }
    
    @discardableResult
    func openMockPage(_ pageLink: MockPageLink) -> WebTestView {
        let omniboxView = OmniBoxTestView()
        omniboxView.searchInOmniBox(pageLink.rawValue, true)
        return WebTestView()
    }
    
    func getMockPageUrl(_ pageLink: MockPageLink) -> String {
        return pageLink.rawValue
    }
    
}
