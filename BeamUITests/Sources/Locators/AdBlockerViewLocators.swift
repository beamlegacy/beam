//
//  AdBlockerViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation

enum AdBlockerViewLocators {
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case siteBlockedByBeamText = "Site is blocked by Beam"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case justThisTimeButton = "Just this time"
        case permanentlyButton = "Permanently"
    }
}
    
