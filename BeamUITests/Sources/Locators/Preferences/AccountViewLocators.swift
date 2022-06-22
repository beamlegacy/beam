//
//  AccountTestViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation

enum AccountViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case signinButton = "Sign In..."
        case signupButton = "Sign Up"
        case forgotPassButton = "Forgot Password"
        case refreshTokenButton = "Refresh Token"
        case connectBeamButton = "Connect to Beam..."
        case signOutButton = "Sign Out..."
        case savePKButton = "Save Private Key..."
        case deleteDBButton = "Delete Database..."
        case pkLabelButton = "pk-label"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case login = "johnnyappleseed@apple.com"
        case password = "Enter your password"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case pkLabel = "Save your private key as a .beamkey file."
        case deleteDBLabel = "All your notes will be deleted and cannot be recovered."
        case encryptionLabel = "Your private key is used to sync your account and decrypt your notes on Beam Web. Click to copy it and paste it on Beam Web."
    }
    
}
