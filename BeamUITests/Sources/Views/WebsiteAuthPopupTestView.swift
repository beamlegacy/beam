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
        textField(WebsiteAuthPopupViewLocators.TextFields.loginField.accessibilityIdentifier).doubleClick()
        textField(WebsiteAuthPopupViewLocators.TextFields.loginField.accessibilityIdentifier).typeText(login)

        NSPasteboard.general.setString(password, forType: NSPasteboard.PasteboardType.string)
        secureTextField(WebsiteAuthPopupViewLocators.TextFields.passwordField.accessibilityIdentifier).doubleClick()
        app.menuItems["Paste"].click()
        
        sleep(4) //temp solution between pasting and auth action
        staticText(WebsiteAuthPopupViewLocators.Buttons.connectButton.accessibilityIdentifier).doubleClick()
        
        return AppWebsiteTestView()
    }
    
    func cancelAuthentication() -> AppWebsiteTestView {
        staticText(WebsiteAuthPopupViewLocators.Buttons.cancelButton.accessibilityIdentifier).click()
        return AppWebsiteTestView()
    }
}
