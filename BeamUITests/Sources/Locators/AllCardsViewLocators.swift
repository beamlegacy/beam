//
//  AllCardsViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation

enum AllCardsViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case newCardButton = "tool new"
        case journalButton = "journal"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case newCardField = "New Private Card"
    }
    
    enum ColumnCells: String, CaseIterable, UIElement {
        case cardTitleColumnCell = "Title"
    }
    
    enum Images: String, CaseIterable, UIElement {
        case singleCardEditor = "editor-options"
        case allCardsEditor = "editor-breadcrumb_down"
    }
    
    enum MenuItems: String, CaseIterable, UIElement {
        case deleteNotes = "deleteNotes"
    }
    
    enum Others: String, CaseIterable, UIElement {
        case referenceSection = "ReferencesSection"
        case disclosureTriangle = "disclosure triangle"
    }
}
