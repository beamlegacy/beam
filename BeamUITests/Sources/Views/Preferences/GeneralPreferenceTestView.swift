//
//  GeneralPreferenceTestView.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest

class GeneralPreferenceTestView: PreferencesBaseView {
    
    func getStartBeamWithOpenedTabsElement() -> XCUIElement {
        return checkBox(GeneralPreferencesViewLocators.Checkboxes.startBeam.accessibilityIdentifier)
    }
    
}
