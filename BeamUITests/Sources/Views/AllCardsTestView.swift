//
//  AllCardsView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class AllCardsTestView: BaseView {
    
    func getCardsNames() -> [XCUIElement]{
        return app.windows.staticTexts.matching(identifier: AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getNumberOfCards() -> Int {
        getCardsNames().count
    }
    
    @discardableResult
    func addNewCard(_ cardName: String) -> AllCardsTestView {
        XCTContext.runActivity(named: "Create a card named '\(cardName)' using + icon") {_ in
            tableTextField(AllCardsViewLocators.TextFields.newCardField.accessibilityIdentifier).doubleClick()
            app.typeText(cardName)
            tableImage(AllCardsViewLocators.Buttons.newCardButton.accessibilityIdentifier).click()
            return self
        }
    }
    
    func isCardNameAvailable(_ cardName: String) -> Bool {
        let cards = getCardsNames()
        var i = cards.count
        repeat {
            let cardInList = cards[i - 1].value as? String
            if cardInList == cardName {
                return true
            }
            i -= 1
        } while i > 0
        return false
    }
    
    func selectCardByName(_ cardName: String) -> AllCardsTestView {
        app.windows.tables.staticTexts[AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier].click()
        return self
    }
    
    func openJournal() -> JournalTestView {
        button(AllCardsViewLocators.Buttons.journalButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
}
