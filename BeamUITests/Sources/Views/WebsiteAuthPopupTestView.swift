//
//  WebsiteAuthPopupTestView.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import AppKit

class WebsiteAuthPopupTestView: BaseView {
    
    func authenticate(_ login: String, _ password: String) -> AppWebsiteTestView {
        textField(WebsiteAuthPopupViewLocators.TextFields.loginField.accessibilityIdentifier).tapInTheMiddle()
        textField(WebsiteAuthPopupViewLocators.TextFields.loginField.accessibilityIdentifier).typeSlowly(login, everyNChar: 2)

        secureTextField(WebsiteAuthPopupViewLocators.TextFields.passwordField.accessibilityIdentifier).tapInTheMiddle()
        secureTextField(WebsiteAuthPopupViewLocators.TextFields.passwordField.accessibilityIdentifier).typeSlowly(password, everyNChar: 2)
        
        staticText(WebsiteAuthPopupViewLocators.Buttons.connectButton.accessibilityIdentifier).tapInTheMiddle()
        
        return AppWebsiteTestView()
    }
    
    func cancelAuthentication() -> AppWebsiteTestView {
        staticText(WebsiteAuthPopupViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return AppWebsiteTestView()
    }
}
