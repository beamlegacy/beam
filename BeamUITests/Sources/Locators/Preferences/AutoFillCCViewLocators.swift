//
//  AutoFillCCViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/05/2022.
//

import Foundation

enum AutofillCCViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelButton = "Cancel"
        case fillButton = "Fill"
        case removeButton = "Remove"
    }

    enum StaticTexts: String, CaseIterable, UIElement {
        case windowTitle = "Choose a credit card"
    }
}
