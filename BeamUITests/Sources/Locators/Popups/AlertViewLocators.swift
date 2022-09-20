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
        case signOutButton = "Sign Out"
        case forgetButton = "Forget"
        case dontAllowButton = "Don’t Allow"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case connectBeam = "Connect to Beam"
        case connectDescription = "Connect to Beam to sync, encrypt and publish your notes."
        case connectDescriptionTabGroups = "Connect to Beam to share your tab groups."
        case tooManyPinnedNotes = "Too many pinned notes"
        case fivePinnedNotesMax = "You can only have 5 pinned notes.\nUnpin some notes to pin new ones."
        case signOutConfirmation = "Are you sure you want to sign out?"
        case deleteDBConfirmation = "Are you sure you want to delete all your graphs?"
        case forgetTabGroupTitle = "Forget tab group"
        case forgetTabGroupBody = "Are you sure you want to forget the tab group “%tabGroupName%”? Forgotten tab groups cannot be recovered."
        case deleteTabGroupTitle = "Delete tab group"
        case deleteCapturedTabGroupBody = "Are you sure you want to delete the tab group “%tabGroupName%” saved in “%noteTitle%”?\nDeleted tab groups cannot be recovered."
        case deleteNotCapturedTabGroupBody = "Are you sure you want to delete the shared tab group “%tabGroupName%”?\nDeleted tab groups cannot be recovered."
    }
    
    enum Checkboxes: String, CaseIterable, UIElement {
        case deleteAllCheckbox = "Delete all data on this device"
    }

}
