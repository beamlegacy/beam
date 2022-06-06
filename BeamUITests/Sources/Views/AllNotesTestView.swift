//
//  AllCardsView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class AllNotesTestView: BaseView {

    @discardableResult
    func waitForAllCardsViewToLoad() -> Bool {
        return app.tables.firstMatch.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).firstMatch
            .waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
    @discardableResult
    func waitForCardTitlesToAppear() -> Bool {
        return staticText(AllNotesViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }

    @discardableResult
    func deleteAllCards() -> AllNotesTestView {
        triggerAllCardsMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func deleteCardByIndex(_ index: Int) -> AllNotesTestView {
        getCardsNamesElements()[index].hover()
        triggerSingleCardMenuOptionAction(.deleteNotes)
        AlertTestView().confirmDeletion()
        return self
    }
    
    @discardableResult
    func triggerAllCardsMenuOptionAction(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleCardEditor.accessibilityIdentifier).element(boundBy: 1).clickOnExistence()
        //Old way to click editor option
        //image(AllNotesViewLocators.Images.allCardsEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    @discardableResult
    func triggerSingleCardMenuOptionAction(_ action: AllNotesViewLocators.MenuItems) -> AllNotesTestView {
        app.windows.children(matching: .image).matching(identifier: AllNotesViewLocators.Images.singleCardEditor.accessibilityIdentifier).element(boundBy: 0).clickOnExistence()
        //Old way to click editor option
        //image(AllNotesViewLocators.Images.singleCardEditor.accessibilityIdentifier).clickOnExistence()
        menuItem(action.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func getCardsNamesElements() -> [XCUIElement]{
        return app.windows.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier).allElementsBoundByIndex
    }
    
    func getCardsNamesElementQuery() -> XCUIElementQuery {
        return app.windows.staticTexts.matching(identifier: AllNotesViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier)
    }
    
    func getCardNameValueByIndex(_ index: Int) -> String {
        return self.getElementStringValue(element: getCardsNamesElements()[index])
    }
    
    func getNumberOfCards() -> Int {
        getCardsNamesElements().count
    }
    
    @discardableResult
    func addNewCard(_ cardName: String) -> AllNotesTestView {
        XCTContext.runActivity(named: "Create a note named '\(cardName)' using + icon") {_ in
            tableTextField(AllNotesViewLocators.TextFields.newPrivateNote.accessibilityIdentifier).doubleClick()
            app.typeText(" " + cardName) //Workaround for CI that skips chars in the end
            tableImage(AllNotesViewLocators.Buttons.newCardButton.accessibilityIdentifier).click()
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
        app.windows.tables.staticTexts[AllNotesViewLocators.ColumnCells.cardTitleColumnCell.accessibilityIdentifier].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
        return CardTestView()
    }
    
    @discardableResult
    func openCardByName(cardTitle: String) -> CardTestView {
        var elementFound = false
        mainLoop: for element in self.getCardsNamesElements(){
            if getElementStringValue(element: element) == cardTitle {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.9)).tap()
                elementFound = true
                break mainLoop
            }
        }
        XCTAssertTrue(elementFound, "\(cardTitle) was not found in All Notes list")
        return CardTestView()
    }
    
    @discardableResult
    func openJournal() -> JournalTestView {
        button(AllNotesViewLocators.Buttons.journalButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
    
    func getPublishInstructionsLabel() -> XCUIElement {
        return label(AllNotesViewLocators.StaticTexts.publishInstruction.accessibilityIdentifier)
    }
    
    @discardableResult
    func openTableView(_ item: AllNotesViewLocators.ViewMenuItems) -> AllNotesTestTable {
        image(AllNotesViewLocators.Images.allCardsEditor.accessibilityIdentifier).tapInTheMiddle()
        menuItem(item.accessibilityIdentifier).clickOnExistence()
        return AllNotesTestTable()
    }
    
    func getViewCountValue() -> Int {
        let predicate = NSPredicate(format: "value BEGINSWITH 'All (' OR value BEGINSWITH 'Private (' OR value BEGINSWITH 'Published (' OR value BEGINSWITH 'On Profile ('")
        let viewCounterElement = app.windows.staticTexts.matching(predicate).firstMatch
        let viewStringValue = getElementStringValue(element: viewCounterElement).slice(from: "(", to: ")")!
        return Int(viewStringValue) ?? 0
    }
    
}
