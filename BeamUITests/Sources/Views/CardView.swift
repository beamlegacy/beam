//
//  CardView.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

class CardTestView: BaseView {
    
    var cardTitle: XCUIElement { return textField(CardViewLocators.TextFields.cardTitle.accessibilityIdentifier)}
    
    func waitForCardViewToLoad() -> Bool {
        return scrollView(CardViewLocators.ScrollViews.noteView.accessibilityIdentifier)
            .waitForExistence(timeout: implicitWaitTimeout)
    }
    
    func openEditorOptions() {
        image(CardViewLocators.Buttons.editorOptions.accessibilityIdentifier).click()
    }
    
    func getCardTitle() -> String {
        return cardTitle.value as? String ?? "nil"
    }
    
}
