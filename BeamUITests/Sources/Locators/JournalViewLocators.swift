//
//  JournalViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum JournalViewLocators {
    
    enum ScrollViews: String, CaseIterable, UIElement {
        case journalScrollView = "journalView"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case updateNowButton = "Update now"
    }
    
}
