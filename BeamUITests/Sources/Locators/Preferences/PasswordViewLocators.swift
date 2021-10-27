//
//  PasswordViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation

enum PasswordViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelButton = "Cancel"
    }

    enum StaticTexts: String, CaseIterable, UIElement {
        case windowTitle = "Choose a login to fill"
    }
}
