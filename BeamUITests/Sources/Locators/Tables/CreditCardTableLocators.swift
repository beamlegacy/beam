//
//  CreditCardTableLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 11.05.2022.
//

import Foundation

enum CreditCardTableLocators {
    
    enum TextFields: String, CaseIterable, UIElement {
        case cardHolderTextField = "Cardholder"
        case cardNumberTextField = "Card Number"
        case cardDateTextField = "Card Date"
        case cardDescription = "cardDescription"
    }

    enum Images: String, CaseIterable, UIElement {
        case cardIcon = "Card Icon"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelDeletionButton = "Cancel"
        case confirmDeletionButton = "Remove"
    }
    
}
