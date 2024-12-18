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
        case destinationNoteSearchField = "DestinationNoteSearchField"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case backButton = "goBack"
        case forwardButton = "goForward"
        case homeButton = "journal"
        case openNoteButton = "pivot-card"
        case openWebButton = "pivot-web"
        case downloadsButton = "downloads"
        case downloadDoneButton = "nav-downloads_done"
        case noteSwitcher = "card-switcher"
        case noteSwitcherJournal = "card-switcher-journal"
        case noteSwitcherAllNotes = "card-switcher-all-cards"
        case helpButton = "HelpButton"
    }
    
    enum Labels: String, CaseIterable, UIElement {
        case noteTitleLabel = "DestinationNoteTitle"
    }
    
}
