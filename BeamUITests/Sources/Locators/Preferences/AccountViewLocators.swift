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
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case login = "johnnyappleseed@apple.com"
        case password = "Enter your password"
    }
    
}
