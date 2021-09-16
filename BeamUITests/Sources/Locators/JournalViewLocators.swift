//
//  JournalViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation

enum JournalViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case allCardsMenuButton = "All Cards"
    }
    
    enum ScrollViews: String, CaseIterable, UIElement {
        case journalScrollView = "journalView"
    }
    
}
