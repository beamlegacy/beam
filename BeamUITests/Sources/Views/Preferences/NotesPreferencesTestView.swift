//
//  NotesPreferencesTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.07.2022.
//

import Foundation
import XCTest

class NotesPreferencesTestView: PreferencesBaseView {
    
    func getAlwaysShowBulletsCheckbox() -> XCUIElement {
        return checkBox(NotesPreferencesViewLocators.Checkboxes.alwaysShowBullets.accessibilityIdentifier)
    }
    
}
