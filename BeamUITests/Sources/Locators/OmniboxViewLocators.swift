//
//  OmniboxViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 18.01.2022.
//

import Foundation

enum OmniboxViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case searchFieldClearButton = "clear-search-text"
    }
    
    enum Images: String, CaseIterable, UIElement {
        case incognitoIcon = "browser-incognito"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case incognitoHeader = "You’re Incognito"
        case incognitoDescription = "beam will keep your browsing history private for all tabs in this window.\nAfter your close this window, beam won’t remember the pages you visited, your search history or your autofill information"
    }

}
