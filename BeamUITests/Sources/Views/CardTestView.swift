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
    
    @discardableResult
    func publishCard() -> CardTestView {
        image(CardViewLocators.Buttons.editorButton.accessibilityIdentifier).click()
        _ = staticText(CardViewLocators.StaticTexts.publishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        staticText(CardViewLocators.StaticTexts.publishLabel.accessibilityIdentifier).click()
        return self
    }
    
    @discardableResult
    func unpublishCard() -> CardTestView {
        image(CardViewLocators.Buttons.editorButton.accessibilityIdentifier).click()
        _ = staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).click()
        return self
    }
    
    func getCardNotesForVisiblePart() -> [XCUIElement] {
        return app.windows.textViews.matching(identifier: CardViewLocators.TextFields.noteField.accessibilityIdentifier).allElementsBoundByIndex
    }
}
