//
//  SearchViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation

enum SearchViewLocators {
    
    enum StaticTexts: String, CaseIterable, UIElement  {
        case emptySearchResult = "Not found"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case forwardButton = "find-forward"
        case backwardButton = "find-previous"
        case closeButton = "tool-close"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "search-field"
    }
    
}
