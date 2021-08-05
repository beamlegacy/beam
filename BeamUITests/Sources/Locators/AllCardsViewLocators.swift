//
//  AllCardsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation

enum AllCardsViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case newCardButton = "tabs new"
        case journalButton = "journal"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case newCardField = "New Private Card"
    }
    
    enum ColumnCells: String, CaseIterable, UIElement {
        case cardTitleColumnCell = "Title"
    }
}
