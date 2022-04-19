//
//  AlertViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 06/10/2021.
//

import Foundation

enum AlertViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case deleteButton = "Delete"
        case cancelButton = "Cancel"
        case connectButton = "Connect"
        case removeButton = "Remove"
        case notNowButton = "Not Now"
        case savePasswordButton = "Save Password"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case connectBeam = "Connect to Beam"
        case connectDescription = "Connect to Beam to sync, encrypt and publish your notes."
    }

}
