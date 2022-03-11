//
//  TabsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum WebViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case closeTabButton = "tabs-close_xs"
        case destinationCard = "DestinationNoteTitle"
        case goToJournalButton = "journal"
    }
    
    enum SearchFields: String, CaseIterable, UIElement {
        case destinationCardSearchField = "DestinationNoteSearchField"
    }
    
    enum Tabs: String, CaseIterable, UIElement {
        case tabPrefix = "browserTab-"
        case tabURL = "browserTabURL"
        case tabTitle = "browserTabTitle"
    }
    
    enum Other: String, CaseIterable, UIElement {
        case autocompleteResult = "autocompleteResult"
    }
    
}
