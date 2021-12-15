//
//  WebsiteAuthPopupVewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation

    
enum WebsiteAuthPopupViewLocators {
    
    enum TextFields: String, CaseIterable, UIElement {
        case loginField = "User name"
        case passwordField = "Password"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelButton = "Cancel"
        case connectButton = "Connect"
    }
    
    enum Checkboxes: String, CaseIterable, UIElement {
        case savePasswordCheckbox = "Save login details"
    }
    
    enum Labels: String, CaseIterable, UIElement {
        case titleLabel = "Connect to rails.beamapp.co:443"
        case descriptionLabel = "Your login information will be sent securely."
    }

}
    

