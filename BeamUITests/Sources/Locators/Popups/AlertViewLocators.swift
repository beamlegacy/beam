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
        case okButton = "OK"
        case cancelButton = "Cancel"
        case connectButton = "Connect"
        case removeButton = "Remove"
        case notNowButton = "Not Now"
        case savePasswordButton = "Save Password"
        case saveCCButton = "Save Credit Card"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case connectBeam = "Connect to Beam"
        case connectDescription = "Connect to Beam to sync, encrypt and publish your notes."
        case tooManyPinnedNotes = "Too many pinned notes"
        case fivePinnedNotesMax = "You can only have 5 pinned notes.\nUnpin some notes to pin new ones."
    }

}
