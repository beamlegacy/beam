//
//  CreditCardTableLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 11.05.2022.
//

import Foundation

enum CreditCardTableLocators {
    
    enum TextFields: String, CaseIterable, UIElement {
        case descriptionTextField = "preferences credit card"
        case cardHolderTextField = "Cardholder"
        case cardNumberTextField = "Card Number"
        case cardDateTextField = "Card Date"
        case cardDescription = "cardDescription"
    }
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelDeletionButton = "Cancel"
        case confirmDeletionButton = "Remove"
    }
    
}
