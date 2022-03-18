//
//  SignUpAutocomplete.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation
import XCTest

class SignUpAutocompleteTests: BaseTest {
    
    let passwordPopup = PasswordSuggestionPopupTestView()
    let shortcutsHelper = ShortcutsHelper()
    let mockPage = MockHTTPWebPages()
    let uiMenuBar = UITestsMenuBar()

    let signUpPageURL = "http://signup.form.lvh.me:8080/"
    let signInPageURL = "http://signin.form.lvh.me:8080/"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        uiMenuBar.destroyDB()
            .startMockHTTPServer()
    }
    
    func testUseAutogeneratedPassword() {
        OmniBoxTestView().searchInOmniBox(signUpPageURL, true)
        
        step("WHEN I click in the password field"){
            mockPage.getPasswordFieldElement().tapInTheMiddle()
        }
        
        step("THEN I see autogenerated password suggestion pop-up"){
            XCTAssertTrue(passwordPopup.doesTitleExist())
            XCTAssertTrue(passwordPopup.doesDescriptionExist())
        }

        step("WHEN I click Use autogenerated password option"){
            passwordPopup.getUsePasswordButton().clickOnHittable()
        }

        step("THEN I see password fields are populated with chars and password pop-up disappears"){
            XCTAssertGreaterThan(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement()).count, 8)
            XCTAssertGreaterThan(mockPage.getElementStringValue(element: mockPage.getConfirmPasswordFieldElement()).count, 8)
            XCTAssertFalse(passwordPopup.doesTitleExist())
        }

        step("WHEN I click Don't Use autogenerated password option"){
            shortcutsHelper.shortcutActionInvoke(action: .reloadPage)
            mockPage.getPasswordFieldElement().tapInTheMiddle()
            passwordPopup.getDontUseButton().clickOnHittable()
        }

        step("THEN I see autogenerated password pop-up disappears and password fields are empty"){
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement()) , emptyString)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getConfirmPasswordFieldElement()) , emptyString)
            XCTAssertFalse(passwordPopup.doesTitleExist())
        }

    }
    
    func testPasswordSuggestionIsUnavailableForSignInPages() {
        OmniBoxTestView().searchInOmniBox(signInPageURL, true)
        
        step("WHEN I click on Password field"){
            mockPage.getPasswordFieldElement(false).tapInTheMiddle()
        }
        
        step("THEN no password suggestion appears"){
            XCTAssertFalse(passwordPopup.doesTitleExist())
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(false)) , emptyString)
        }

    }
    
    
}
