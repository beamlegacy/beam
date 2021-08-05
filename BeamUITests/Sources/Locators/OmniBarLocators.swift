//
//  OmniBarLocators.swift
//  BeamUITests
//
//  Created by Andrii on 28.07.2021.
//

import Foundation

enum OmniBarLocators {
    
    enum SearchFields: String, CaseIterable, UIElement {
        case omniSearchField = "OmniBarSearchField"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case refreshButton = "refresh"
        case backButton = "goBack"
        case forwardButton = "goForward"
        case homeButton = "journal"
        case openCardButton = "pivot-card"
        case openWebButton = "pivot-web"
        case downloadsButton = "nav-downloads"
    }
    
}
