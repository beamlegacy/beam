//
//  NotesPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.07.2022.
//

import Foundation

enum NotesPreferencesViewLocators {
    
    enum Checkboxes: String, CaseIterable, UIElement {
        case alwaysShowBullets = "Always show bullets"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case indentationLabel = "Indentation:"
    }
    
}
