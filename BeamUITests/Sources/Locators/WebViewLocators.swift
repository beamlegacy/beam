//
//  TabsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum WebViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case newTabButton = "tabs-new"
        case destinationCard = "DestinationNoteTitle"
    }
    
    enum SearchFields: String, CaseIterable, UIElement {
        case destinationCardSearchField = "DestinationNoteSearchField"
    }
    
}
