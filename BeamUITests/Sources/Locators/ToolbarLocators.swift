//
//  ToolbarLocators.swift
//  BeamUITests
//
//  Created by Andrii on 28.07.2021.
//

import Foundation

enum ToolbarLocators {
    
    enum SearchFields: String, CaseIterable, UIElement {
        case omniSearchField = "OmniboxSearchField"
        case destinationCardSearchField = "DestinationNoteSearchField"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case backButton = "goBack"
        case forwardButton = "goForward"
        case homeButton = "journal"
        case openCardButton = "pivot-card"
        case openWebButton = "pivot-web"
        case downloadsButton = "nav-downloads"
        case downloadDoneButton = "nav-downloads_done"
        case cardSwitcher = "card-switcher"
        case cardSwitcherJournal = "card-switcher-journal"
        case cardSwitcherAllCards = "card-switcher-all-cards"
    }
    
    enum Labels: String, CaseIterable, UIElement {
        case cardTitleLabel = "DestinationNoteTitle"
    }
    
}
