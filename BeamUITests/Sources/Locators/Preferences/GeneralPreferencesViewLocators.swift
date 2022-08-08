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
        case highlightTab = "Press Tab to highlight each item on a web page"
        case forceClickAndHapticFeedback = "Force Click and haptic feedback"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case lightTheme = "Light"
        case darkTheme = "Dark"
        case systemTheme = "System"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case startBeamlabel = "Always start on the web if there are pinned \nor opened tabs."
        case appearanceLabel = "Appearance:"
        case accessibilityLabel = "Accessibility:"
        case highlightCheckboxDescription = "Option-Tab to highlights each item."
    }
    
}
