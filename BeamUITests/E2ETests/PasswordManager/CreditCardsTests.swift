//
//  CreditCardsTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 10.05.2022.
//

import Foundation
import XCTest

class CreditCardsTests: BaseTest {
    
    let expectedCardDescription = "TestDescription"
    let expectedCardHolder = "TestHolder"
    let expectedCardNumber = "1234 5678 1234 5670"
    let expectedCardDueDate = "01/27"

    var creditCardsTable: CreditCardsTestTable!
    var passwordPreferencesView: PasswordPreferencesTestView!
    var creditCardView: CreditCardTestView!
    
    private func launchAppAndOpenEditCreditCardsTable(populateCardsDB: Bool) {
        
        step("GIVEN I open Credit cards table in Preferences") {
            launchApp()
            
            if populateCardsDB {
                uiMenu.populateCreditCardsDB()
            }
            
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            creditCardView = PasswordPreferencesTestView().clickEditCreditCardButton()
        }
    }
    
    @discardableResult
    private func openAndEditFirstCreditCardFromDB() -> RowCreditCardsTestTable {
        
        creditCardView.getCardTextFieldElement(.description).tapInTheMiddle()
        creditCardView.shortcutHelper.shortcutActionInvoke(action: .selectAll)
        creditCardView.typeKeyboardKey(.delete)
        creditCardView.app.typeSlowly("test", everyNChar: 2)
        
        creditCardView.populateCreditCardField(.cardHolder, "edited", true)
        
        creditCardView.getCardTextFieldElement(.cardNumber).tapInTheMiddle()
        creditCardView.shortcutHelper.shortcutActionInvoke(action: .endOfLine)
        creditCardView.typeKeyboardKey(.delete, 4)
        creditCardView.app.typeSlowly("0008", everyNChar: 2)
        
        creditCardView.getCardTextFieldElement(.expirationDate).tapInTheMiddle()
        creditCardView.shortcutHelper.shortcutActionInvoke(action: .endOfLine)
        creditCardView.typeKeyboardKey(.leftArrow, 3)
        creditCardView.typeKeyboardKey(.delete)
        creditCardView.app.typeText("9")
        
        return RowCreditCardsTestTable("test", "John Appleseededited", "xxxx-xxxx-xxxx-0008", "09/25")

    }
    
    func testCreditCardCreation() {
        
        launchAppAndOpenEditCreditCardsTable(populateCardsDB: false)

        step("When I add a Credit Card in Preferences ") {
            creditCardView
                .clickAddCreditCardButton()
                .populateCreditCardField(.description, expectedCardDescription)
                .populateCreditCardField(.cardHolder, expectedCardHolder)
                .populateCreditCardField(.cardNumber, expectedCardNumber, true)
                .populateCreditCardField(.expirationDate, expectedCardDueDate, true)
                .clickAddCreditCardCreationButton()
            waitForDoesntExist(creditCardView.getAddCreditCardCreationButton())
        }
        
        step("Then it is successfully displayed in Credit cards table") {
            let expectedCreditCardRow = RowCreditCardsTestTable(expectedCardDescription, expectedCardHolder, "xxxx-xxxx-xxxx-5670", expectedCardDueDate)
            let comparisonResult = CreditCardsTestTable().rows[0].isEqualTo(expectedCreditCardRow)
            XCTAssertTrue(comparisonResult.0, comparisonResult.1)
        }
    }
    
    func testCreditCardDeletion() {
        
        launchAppAndOpenEditCreditCardsTable(populateCardsDB: true)
        
        step("WHEN I cancel Credit card item deletion") {
            XCTAssertFalse(creditCardView.isDeleteCreditCardButtonEnabled())
            creditCardsTable = CreditCardsTestTable().selectCreditCardItem(index: 0)
            creditCardView
                .clickDeleteCreditCardButton()
                .cancelCreditCardDeletion()
        }
        
        step("THEN all Credit card items are displayed") {
            XCTAssertEqual(creditCardsTable.getNumberOfVisibleItems(), 2)
        }
        
        step("WHEN I confirm Credit card item deletion") {
            creditCardsTable.selectCreditCardItem(index: 0)
            creditCardView
                .clickDeleteCreditCardButton()
                .submitCreditCardDeletion()
        }
        
        step("THEN one Credit card item is removed") {
            XCTAssertEqual(creditCardsTable.getNumberOfVisibleItems(), 1)
        }
    }
    
    func testCancelCreditCardItemEditing() {
        var rowBeforeEdit = RowCreditCardsTestTable()
        launchAppAndOpenEditCreditCardsTable(populateCardsDB: true)
        
        step("WHEN edit Credit card data and click Cancel") {
            rowBeforeEdit = CreditCardsTestTable().rows[0]
            creditCardsTable = CreditCardsTestTable().openEditCardView(index: 0)
            self.openAndEditFirstCreditCardFromDB()
            creditCardView.cancelCreditCardDeletion()
        }
        
        step("THEN the Credit Card item is not changed") {
            let compareResult = CreditCardsTestTable().rows[0].isEqualTo(rowBeforeEdit)
            XCTAssertTrue(compareResult.0, compareResult.1)
        }
    }
    
    func testConfirmCreditCardItemEditing() {
        
        launchAppAndOpenEditCreditCardsTable(populateCardsDB: true)
        var expectedRowAfterEdit: RowCreditCardsTestTable!
        
        step("WHEN edit Credit card data and click Done") {
            creditCardsTable = CreditCardsTestTable().openEditCardView(index: 0)
            expectedRowAfterEdit = self.openAndEditFirstCreditCardFromDB()
            creditCardView.clickCreditCardEditDoneButton()
        }
        
        step("THEN the Credit Card item changes are applied accordingly") {
            let compareResult = CreditCardsTestTable().rows[0].isEqualTo(expectedRowAfterEdit)
            XCTAssertTrue(compareResult.0, compareResult.1)
        }
    }
    
    // Other tests to be added once https://linear.app/beamapp/issue/BE-3836/payment-autofill-ui fixes are applied
    
}
