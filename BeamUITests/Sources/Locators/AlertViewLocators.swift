//
//  AlertViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 06/10/2021.
//

import Foundation

enum AlertViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case alertDeleteButton = "Delete..."
        case alertCancelButton = "Cancel"
        case alertRemoveButton = "Remove"
        case alertNotNowButton = "Not Now"
        case alertSavePasswordButton = "Save Password"
    }

}
