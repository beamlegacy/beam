//
//  CreditCardTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 16.05.2022.
//

import Foundation
import XCTest

class CreditCardTestView: BaseView {
    
    private let passwordsWindowTitle = "Passwords"
    private let windowSheetTitle = "Credit Cards"
    
    @discardableResult
    func clickAddCreditCardButton() -> CreditCardTestView {
        if BaseTest().isBigSurOS() {
            button(PasswordPreferencesViewLocators.Buttons.addCreditCardButton.accessibilityIdentifier).clickOnExistence()
        } else {
            XCTAssertTrue(group(PasswordPreferencesViewLocators.Groups.addRemoveCreditCard.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            group(PasswordPreferencesViewLocators.Groups.addRemoveCreditCard.accessibilityIdentifier).children(matching: .button).firstMatch.clickOnExistence()
        }
        return self
    }
    
    @discardableResult
    func clickDeleteCreditCardButton() -> CreditCardTestView{
        getDeleteCreditCardButton().clickOnExistence()
        return self
    }
    
    @discardableResult
    func populateCreditCardField(_ index: CreditCardFieldToFill, _ value: String, _ typeSlowly: Bool = false, _ appendChanges: Bool = false) -> CreditCardTestView {
        let textField = getCardTextFieldElement(index)
        
        if appendChanges {
            textField.tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .endOfLine)
            textField.typeText(value)
        } else {
            textField.clickOnExistence()
        }
        //reduces flakiness for Big Sur card number typing
        if typeSlowly {
            textField.typeSlowly(value, everyNChar: 3)
        } else {
            textField.typeText(value)
        }
        
        return self
    }
    
    func getCardTextFieldElement(_ index: CreditCardFieldToFill) -> XCUIElement {
        return app.windows[passwordsWindowTitle].sheets.containing(.staticText, identifier:PasswordPreferencesViewLocators.Other.creditCards.accessibilityIdentifier).children(matching: .sheet).element.children(matching: .textField).element(boundBy: index.rawValue)
    }
    
    @discardableResult
    func clickAddCreditCardCreationButton() -> CreditCardTestView {
        app.windows[passwordsWindowTitle].sheets.sheets.buttons[PasswordPreferencesViewLocators.Buttons.addCardButton.accessibilityIdentifier].clickOnHittable()
        return self
    }
    
    @discardableResult
    func getAddCreditCardCreationButton() -> XCUIElement {
        return app.windows[passwordsWindowTitle].sheets.sheets.buttons[PasswordPreferencesViewLocators.Buttons.addCardButton.accessibilityIdentifier]
    }
    
    @discardableResult
    func clickCancelCreditCardCreationButton() -> CreditCardTestView {
        button(PasswordPreferencesViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnHittable()
        return self
    }
    
    @discardableResult
    func clickCreditCardsTableViewDoneButton() -> CreditCardTestView {
        getCreditCardsTableDoneButton().tapInTheMiddle()
        return self
    }
    
    func getCreditCardsTableDoneButton() -> XCUIElement {
        return button(PasswordPreferencesViewLocators.Buttons.doneButton.accessibilityIdentifier)
    }
    
    func clickCreditCardEditDoneButton() {
        let doneButton = getCreditCardsEditDoneButton()
        doneButton.tapInTheMiddle()
        waitForDoesntExist(doneButton)
    }
    
    func isCreditCardEditDoneButtonEnabled() -> Bool {
        return getCreditCardsEditDoneButton().isEnabled
    }
    
    func getCreditCardsEditDoneButton() -> XCUIElement {
        return app.windows.sheets.containing(.staticText, identifier: windowSheetTitle).children(matching: .sheet).element.buttons[PasswordPreferencesViewLocators.Buttons.doneButton.accessibilityIdentifier]
    }
    
    func isDeleteCreditCardButtonEnabled() -> Bool {
        return getDeleteCreditCardButton().isEnabled
    }
    
    func getDeleteCreditCardButton() -> XCUIElement {
        if BaseTest().isBigSurOS() {
            return button(PasswordPreferencesViewLocators.Buttons.removeCreditCardButton.accessibilityIdentifier)
        } else {
            XCTAssertTrue(group(PasswordPreferencesViewLocators.Groups.addRemoveCreditCard.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            return group(PasswordPreferencesViewLocators.Groups.addRemoveCreditCard.accessibilityIdentifier).children(matching: .button).lastMatch
        }
    }
    
    func cancelCreditCardDeletion() {
        let cancelButton = button(CreditCardTableLocators.Buttons.cancelDeletionButton.accessibilityIdentifier)
        cancelButton.clickOnExistence()
        waitForDoesntExist(cancelButton)
    }
    
    func submitCreditCardDeletion() {
        button(CreditCardTableLocators.Buttons.confirmDeletionButton.accessibilityIdentifier).clickOnExistence()
    }
    
    enum CreditCardFieldToFill: Int, CaseIterable {
        case description = 0
        case cardHolder = 1
        case cardNumber = 2
        case expirationDate = 3
    }
}
