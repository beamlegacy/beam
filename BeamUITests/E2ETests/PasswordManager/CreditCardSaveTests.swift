//
//  CreditCardSaveTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/05/2022.
//

import Foundation
import XCTest

class CreditCardSaveTests: BaseCreditCardTest {
    
    let alertView = AlertTestView()
    var ccPrefView = AutoFillCCTestView()
    let view = "Payment"
    let fakeCardNumber = "5425233430109903"
    let fakeSecurityCode = "123"
    let expectedCardOwnerName = "Quentin Tester"
    let expectedCardExpDate = "04/2023"
    let expectedCardHiddenNumber = "xxxx-xxxx-xxxx-9903"
        
    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
    }
    
    private func fillDataWithoutPwManager(field: String, data: String) {
        step("When I fill \(field) field") {
            mockPage.getUsernameFieldElement(title: field, inView: view).clickOnExistence()
            mockPage.getUsernameFieldElement(title: field, inView: view).clickClearAndType(data)
            mockPage.typeKeyboardKey(.escape) // In case of autocomplete
        }
    }
    
    func testSaveCC(){
        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }
        
        fillDataWithoutPwManager(field: creditCardNumberLabel, data: fakeCardNumber)
        fillDataWithoutPwManager(field: creditCardExpDateLabel, data: expectedCardExpDate)
        fillDataWithoutPwManager(field: creditCardSecCodeLabel, data: fakeSecurityCode)
        fillDataWithoutPwManager(field: creditCardOwnerNameLabel, data: expectedCardOwnerName)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("And I save the CC") {
            alertView.saveCreditCard(waitForAlertToDisappear: true)
        }
        
        step("Then CC is saved in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            creditCardView = PasswordPreferencesTestView().clickEditCreditCardButton()
            let expectedCreditCardRow = RowCreditCardsTestTable(expectedCardOwnerName, expectedCardOwnerName, expectedCardHiddenNumber, expectedCardExpDate)
            let comparisonResult = CreditCardsTestTable().rows[0].isEqualTo(expectedCreditCardRow)
            XCTAssertTrue(comparisonResult.0, comparisonResult.1)
        }
    }
    
    func testDoNotSaveCC(){
        step("Given I navigate to \(mockPage.getMockPageUrl(.paymentForm))") {
            mockPage.openMockPage(.paymentForm)
        }
        
        fillDataWithoutPwManager(field: creditCardNumberLabel, data: fakeCardNumber)
        fillDataWithoutPwManager(field: creditCardExpDateLabel, data: expectedCardExpDate)
        fillDataWithoutPwManager(field: creditCardSecCodeLabel, data: fakeSecurityCode)
        fillDataWithoutPwManager(field: creditCardOwnerNameLabel, data: expectedCardOwnerName)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("And I do not save the CC") {
            alertView.notNowClick()
        }
        
        step("Then CC is not saved in Preferences") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            PasswordPreferencesTestView().clickEditCreditCardButton()
            XCTAssertEqual(CreditCardsTestTable().getNumberOfVisibleItems(), 0)
        }
    }
    
}
