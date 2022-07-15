//
//  GeneralPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 14.07.2022.
//

import Foundation

enum GeneralPreferencesViewLocators {
    
    enum Checkboxes: String, CaseIterable, UIElement {
        case startBeam = "Start beam with opened tabs"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case startBeamlabel = "Always start on the web if there are pinned \nor opened tabs"
    }
    
}
