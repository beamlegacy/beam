//
//  AllCardsView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class AllCardsTestView: BaseView {

    @discardableResult
    func waitForAllCardsViewToLoad() -> Bool {
        return app.tables.firstMatch.staticTexts.matching(identifier: AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).firstMatch
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForCardTitlesToAppear() -> Bool {
        return staticText(AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }

    @discardableResult
    func deleteAllCards() -> AllCardsTestView {
        triggerAllCardsMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func deleteCardByIndex(_ index: Int) -> AllCardsTestView {
        getCardsNamesElements()[index].hover()
        triggerSingleCardMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func triggerAllCardsMenuOptionAction(_ action: AllCardsViewLocators.MenuItems) -> AllCardsTestView {
        image(AllCardsViewLocators.Images.allCardsEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func triggerSingleCardMenuOptionAction(_ action: AllCardsViewLocators.MenuItems) -> AllCardsTestView {
        image(AllCardsViewLocators.Images.singleCardEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getCardsNamesElements() -> [XCUIElement]{
        return app.windows.staticTexts.matching(identifier: AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getCardsNamesElementQuery() -> XCUIElementQuery {
        return app.windows.staticTexts.matching(identifier: AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier)
    }
    
    func getCardNameValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element: getCardsNamesElements()[index])
    }
    
    func getNumberOfCards() -> Int {
        getCardsNamesElements().count
    }
    
    @discardableResult
    func addNewCard(_ cardName: String) -> AllCardsTestView {
        XCTContext.runActivity(named: "Create a note named '\(cardName)' using + icon") {_ in
            tableTextField(AllCardsViewLocators.TextFields.newCardField.accessibilityIdentifier).doubleClick()
            app.typeText(" " + cardName) //Workaround for CI that skips chars in the end
            tableImage(AllCardsViewLocators.Buttons.newCardButton.accessibilityIdentifier).click()
            return self
        }
    }
    
    func isCardNameAvailable(_ cardName: String) -> Bool {
        let cards = getCardsNamesElements()
        var i = cards.count
        repeat {
            let cardInList = self.getElementStringValue(element: cards[i - 1])
            if cardInList == cardName {
                return true
            }
            i -= 1
        } while i > 0
        return false
    }
    
    @discardableResult
    func openFirstCard() -> CardTestView {
        app.windows.tables.staticTexts[AllCardsViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
        return CardTestView()
    }
    
    @discardableResult
    func openCardByName(cardTitle: String) -> CardTestView {
        var elementFound = false
        self.getCardsNamesElements().forEach{ element in
            if getElementStringValue(element: element) == cardTitle {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
                elementFound = true
                return
            }
        }
        XCTAssertTrue(elementFound, "\(cardTitle) was not found in All Notes list")
        return CardTestView()
    }
    
    @discardableResult
    func openJournal() -> JournalTestView {
        button(AllCardsViewLocators.Buttons.journalButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
}
