//
//  TabsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum WebViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case newTabButton = "tool-new"
        case closeTabButton = "tabs-close_xs"
        case destinationCard = "DestinationNoteTitle"
    }
    
    enum SearchFields: String, CaseIterable, UIElement {
        case destinationCardSearchField = "DestinationNoteSearchField"
    }
    
    enum Images: String, CaseIterable, UIElement {
        case browserTabBar = "browserTabBarView"
    }
    
    enum Other: String, CaseIterable, UIElement {
        case autocompleteResult = "autocompleteResult"
    }
    
}
